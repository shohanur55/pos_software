import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../core/base/failure.dart';
import '../../core/base/result.dart';
import '../../core/constants/storage_keys.dart';
import '../../core/utils/app_logger.dart';
import '../../core/utils/file_name_utils.dart';
import '../../domain/entities/notification_permission_status.dart';
import '../../domain/entities/remote_file_entity.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_error_kind.dart';
import '../../domain/entities/transfer_notification_tap_entity.dart';
import '../../domain/entities/transfer_status.dart';
import '../../domain/entities/transfer_type.dart';
import '../../domain/entities/upload_request_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../models/remote_files_parser.dart';
import '../models/transfer_events.dart';
import '../models/transfer_model.dart';
import '../models/transfer_task_meta.dart';
import '../services/cache/cache_service.dart';
import '../services/cache/session_storage.dart';
import '../services/database/transfer_dao.dart';
import '../services/network/endpoints.dart';
import '../services/network/network_failure_mapper.dart';
import '../services/network/rest_client.dart';
import '../services/system/system_settings_service.dart';
import '../services/transfer/background_transfer_service.dart';
import '../services/transfer/uploaded_name_resolver.dart';

class TransferRepositoryImpl extends TransferRepository {
  TransferRepositoryImpl(
    this._service,
    this._dao,
    this._sessionStorage,
    this._client,
    this._settings,
    this._cache, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackgroundTransferService _service;
  final TransferDao _dao;
  final SessionStorage _sessionStorage;
  final RestClient _client;
  final SystemSettingsService _settings;
  final CacheService _cache;
  final DateTime Function() _clock;
  final Random _random = Random();

  final Map<String, TransferModel> _transfers = {};
  final StreamController<TransferEntity> _updates =
      StreamController<TransferEntity>.broadcast();
  final StreamController<String> _removed =
      StreamController<String>.broadcast();

  /// Serializes everything that mutates [_transfers], so native events and
  /// user actions never interleave halfway through an update.
  Future<void> _queue = Future.value();

  /// Shared by every caller, so a second one never sees a half-filled map.
  Future<void>? _loading;

  /// A native task that vanished is only declared lost after this grace
  /// period, because a freshly enqueued task may not be recorded yet.
  static const Duration _lostTaskGrace = Duration(minutes: 2);

  @override
  Future<Result<List<TransferEntity>, Failure>> getTransfers() {
    return asyncGuard(() async {
      await _ensureLoaded();
      await _serialized(_finalizePending);
      return List<TransferEntity>.of(_transfers.values);
    });
  }

  @override
  Stream<TransferEntity> watchTransfers() => _updates.stream;

  @override
  Stream<String> watchRemovedTransfers() => _removed.stream;

  @override
  Future<Result<TransferEntity, Failure>> startUpload(
    UploadRequestEntity request,
  ) {
    return asyncGuard(() async {
      await _ensureLoaded();
      final session = _requireSession();
      if (!await File(request.filePath).exists()) {
        throw const Failure(
          FailureKind.invalidFile,
          'Upload source is missing',
        );
      }
      final now = _clock();
      final id = _newId();
      final model = TransferModel(
        id: id,
        taskId: id,
        type: TransferType.upload,
        fileName: request.fileName,
        status: TransferStatus.queued,
        createdAt: now,
        updatedAt: now,
        localPath: request.filePath,
        url: Endpoints.uploadUrl,
        totalBytes: request.sizeBytes,
      );
      await _service.enqueueUpload(
        taskId: id,
        filePath: request.filePath,
        authorization: session.authorizationHeader,
        meta: _metaFor(model),
      );
      return _registerStarted(model);
    });
  }

  @override
  Future<Result<TransferEntity, Failure>> startDownload(RemoteFileEntity file) {
    return asyncGuard(() async {
      await _ensureLoaded();
      final duplicate = _transfers.values.any(
        (transfer) =>
            transfer.isDownload &&
            transfer.remoteFileName == file.name &&
            transfer.status.isInProgress,
      );
      if (duplicate) throw Failure(FailureKind.alreadyInProgress, file.name);
      final session = _requireSession();
      // Only prompts on Android 9 and lower; a refusal must not block the
      // download, which then stays in private storage.
      await asyncGuard(_service.ensureSharedStoragePermission);

      final taken = [
        ..._transfers.values
            .where((transfer) => transfer.isDownload)
            .map((transfer) => transfer.fileName),
        ...await _service.existingDownloadNames(),
      ];
      final localName = FileNameUtils.unique(
        FileNameUtils.sanitize(file.name),
        taken,
      );
      final now = _clock();
      final id = _newId();
      final model = TransferModel(
        id: id,
        taskId: id,
        type: TransferType.download,
        fileName: localName,
        remoteFileName: file.name,
        status: TransferStatus.queued,
        createdAt: now,
        updatedAt: now,
        url: file.url,
        totalBytes: file.sizeBytes,
        localPath: await _service.downloadPath(localName),
      );
      await _service.enqueueDownload(
        taskId: id,
        url: file.url,
        fileName: localName,
        authorization: session.authorizationHeader,
        meta: _metaFor(model),
      );
      return _registerStarted(model);
    });
  }

  @override
  Future<Result<void, Failure>> pause(String id) {
    return asyncGuard(() async {
      final model = await _require(id);
      if (!model.status.canPause) {
        throw const Failure(
          FailureKind.notAllowed,
          'Not pausable in this state',
        );
      }
      if (model.isUpload) {
        // A multipart POST cannot continue mid-stream: stop it and keep the row.
        await _serialized(
          () => _commit(
            model.copyWith(
              status: TransferStatus.paused,
              clearTransient: true,
              updatedAt: _clock(),
            ),
          ),
        );
        await _service.cancel(model.taskId);
        return;
      }
      if (!await _service.pauseDownload(model.taskId)) {
        throw const Failure(
          FailureKind.notAllowed,
          'Server does not support pausing',
        );
      }
    });
  }

  @override
  Future<Result<TransferEntity, Failure>> resume(String id) {
    return asyncGuard(() async {
      final model = await _require(id);
      if (!model.status.canResume) {
        throw const Failure(
          FailureKind.notAllowed,
          'Not resumable in this state',
        );
      }
      if (model.isUpload) return _restart(model);
      _requireSession();
      if (await _service.resumeDownload(model.taskId)) {
        final resumed = model.copyWith(
          status: TransferStatus.queued,
          clearError: true,
          updatedAt: _clock(),
        );
        await _serialized(() => _commit(resumed));
        return resumed;
      }
      return _restart(model, notice: TransferErrorKind.resumeFailed);
    });
  }

  @override
  Future<Result<void, Failure>> cancel(String id) {
    return asyncGuard(() async {
      final model = await _require(id);
      if (!model.status.canCancel) {
        throw const Failure(
          FailureKind.notAllowed,
          'Not cancelable in this state',
        );
      }
      await _serialized(
        () => _commit(
          model.copyWith(
            status: TransferStatus.canceled,
            clearTransient: true,
            updatedAt: _clock(),
          ),
        ),
      );
      await _service.cancel(model.taskId);
    });
  }

  @override
  Future<Result<void, Failure>> cancelAllActive() {
    return asyncGuard(() async {
      await _ensureLoaded();
      final active = _transfers.values
          .where((transfer) => transfer.status.canCancel)
          .toList();
      await _serialized(() async {
        for (final model in active) {
          await _commit(
            model.copyWith(
              status: TransferStatus.canceled,
              clearTransient: true,
              updatedAt: _clock(),
            ),
          );
        }
      });
      await Future.wait(active.map((model) => _service.cancel(model.taskId)));
    });
  }

  @override
  Future<Result<TransferEntity, Failure>> retry(String id) {
    return asyncGuard(() async {
      final model = await _require(id);
      if (!model.status.canRetry) {
        throw const Failure(
          FailureKind.notAllowed,
          'Not retryable in this state',
        );
      }
      return _restart(model);
    });
  }

  @override
  Future<Result<void, Failure>> remove(String id) {
    return asyncGuard(() async {
      final model = await _require(id);
      if (!model.status.isFinished) {
        throw const Failure(
          FailureKind.notAllowed,
          'Only finished transfers can be removed',
        );
      }
      await _serialized(() => _delete([model]));
    });
  }

  @override
  Future<Result<void, Failure>> clearFinished() {
    return asyncGuard(() async {
      await _ensureLoaded();
      await _serialized(
        () => _delete(
          _transfers.values
              .where((transfer) => transfer.status.isFinished)
              .toList(),
        ),
      );
    });
  }

  @override
  Future<Result<void, Failure>> openFile(String id) {
    return asyncGuard(() async {
      final model = await _require(id);
      if (!model.isDownload || model.status != TransferStatus.completed) {
        throw const Failure(FailureKind.notFound, 'No saved file');
      }
      final outcome = await _service.openDownload(
        fileName: model.fileName,
        savedPath: model.savedPath,
      );
      switch (outcome) {
        case OpenFileOutcome.opened:
          return;
        case OpenFileOutcome.notFound:
          throw Failure(FailureKind.notFound, model.savedPath);
        case OpenFileOutcome.noApp:
          throw Failure(FailureKind.cannotOpen, model.savedPath);
      }
    });
  }

  @override
  Future<Result<List<TransferEntity>, Failure>> resync() {
    return asyncGuard(() async {
      await _ensureLoaded();
      await _service.resumeFromBackground();
      await _serialized(() async {
        await _reconcileWithNativeRecords();
        await _finalizePending();
      });
      return List<TransferEntity>.of(_transfers.values);
    });
  }

  @override
  Stream<TransferNotificationTapEntity> watchNotificationTaps() =>
      _service.notificationTaps;

  @override
  Future<Result<NotificationPermissionStatus, Failure>>
  notificationPermissionStatus() {
    return asyncGuard(
      () => _service.notificationPermission(
        alreadyAsked: _cache.readBool(StorageKeys.notificationPermissionAsked),
      ),
    );
  }

  @override
  Future<Result<NotificationPermissionStatus, Failure>>
  requestNotificationPermission() {
    return asyncGuard(() async {
      await _cache.writeBool(
        StorageKeys.notificationPermissionAsked,
        value: true,
      );
      return _service.requestNotificationPermission();
    });
  }

  @override
  Future<Result<void, Failure>> openNotificationSettings() =>
      asyncGuard(_settings.openAppSettings);

  @override
  Failure mapException(Object error, StackTrace stackTrace) {
    if (error is FileSystemException) {
      return Failure(FailureKind.storage, error.message);
    }
    return NetworkFailureMapper.map(error);
  }

  /// A failed load (a locked or corrupt database) is not cached, so the next
  /// call tries again instead of leaving the app permanently empty.
  Future<void> _ensureLoaded() {
    return _loading ??= _load().catchError((Object error) {
      _loading = null;
      throw error;
    });
  }

  Future<void> _load() async {
    for (final transfer in await _dao.all()) {
      _transfers[transfer.id] = transfer;
    }
    // Subscribed only after the history is in memory, so an event cannot
    // recreate a row that is about to be loaded. Failures are logged by the
    // queue; nobody awaits event handling.
    _service.events.listen(
      (event) => _serialized(() => _applyEvent(event)).ignore(),
    );
  }

  Future<void> _serialized(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // Keep the queue alive after a failure; the caller still sees the error.
    _queue = next.catchError((Object error, StackTrace stackTrace) {
      logger.e('Transfer update failed', error: error, stackTrace: stackTrace);
    });
    return next;
  }

  /// Stores a newly enqueued transfer. Native events may already have created
  /// the row from task metadata, in which case their status wins.
  Future<TransferModel> _registerStarted(TransferModel initial) async {
    late TransferModel stored;
    await _serialized(() async {
      final existing = _transfers[initial.id];
      stored = existing == null
          ? initial
          : existing.copyWith(
              localPath: initial.localPath,
              url: initial.url,
              totalBytes: existing.totalBytes ?? initial.totalBytes,
              remoteFileName: initial.remoteFileName,
              fileName: initial.fileName,
            );
      await _commit(stored);
    });
    return stored;
  }

  /// Runs the transfer again on a fresh native task with a fresh token.
  Future<TransferModel> _restart(
    TransferModel model, {
    TransferErrorKind? notice,
  }) async {
    final session = _requireSession();
    final oldTaskId = model.taskId;
    final restarted = model.restartedWith(_newId(), _clock(), notice: notice);
    await _serialized(() => _commit(restarted));
    final source = model.localPath;
    if (model.isUpload && (source == null || !await File(source).exists())) {
      await _failRestart(restarted, TransferErrorKind.invalidFile);
      throw const Failure(FailureKind.invalidFile, 'Upload source is gone');
    }
    if (model.isDownload) await _service.cancel(oldTaskId);
    final enqueued = await asyncGuard(
      () => model.isUpload
          ? _service.enqueueUpload(
              taskId: restarted.taskId,
              filePath: source!,
              authorization: session.authorizationHeader,
              meta: _metaFor(restarted),
            )
          : _service.enqueueDownload(
              taskId: restarted.taskId,
              url:
                  restarted.url ??
                  Endpoints.downloadUrl(
                    restarted.remoteFileName ?? restarted.fileName,
                  ),
              fileName: restarted.fileName,
              authorization: session.authorizationHeader,
              meta: _metaFor(restarted),
            ),
    );
    if (enqueued case Error(:final error)) {
      await _failRestart(restarted, TransferErrorKind.unknown);
      throw error;
    }
    _service.deleteRecord(oldTaskId).ignore();
    return restarted;
  }

  /// A restarted row must not sit in `queued` without a native task behind it.
  Future<void> _failRestart(TransferModel restarted, TransferErrorKind kind) {
    return _serialized(
      () => _commit(
        restarted.copyWith(
          status: TransferStatus.failed,
          errorKind: kind,
          updatedAt: _clock(),
        ),
      ),
    );
  }

  Future<void> _applyEvent(TransferTaskEvent event) async {
    final model = _modelFor(event);
    // Events from a task that was replaced by a retry or restart are stale.
    if (model == null || model.taskId != event.taskId) return;
    // User-initiated states are final from our point of view: a paused upload's
    // task was canceled on purpose, and a canceled row stays canceled.
    if (model.status == TransferStatus.canceled) return;
    if (model.isUpload && model.status == TransferStatus.paused) return;

    switch (event) {
      case TransferProgressEvent():
        if (model.status.isFinished) return;
        _emit(model.applyProgress(event, _clock()));
      case TransferStatusEvent():
        await _applyStatus(model, event);
    }
  }

  Future<void> _applyStatus(
    TransferModel model,
    TransferStatusEvent event,
  ) async {
    if (model.status == TransferStatus.completed) return;
    var next = model.applyStatus(event, _clock());
    if (event.status == TransferStatus.completed) {
      if (model.isUpload) {
        final stored = RemoteFilesParser.parseUploaded(event.responseBody);
        next = next.copyWith(remoteFileName: stored?.name ?? model.fileName);
        if (stored == null) _resolveRemoteNameFromList(model).ignore();
        _deletePickedCopy(model);
      } else {
        next = next.copyWith(pendingFinalize: true);
        await _commit(next);
        next = await _finalize(next);
      }
    }
    if (event.status == TransferStatus.running &&
        model.isDownload &&
        !model.canPauseNatively) {
      _probePauseSupport(model.id, model.taskId).ignore();
    }
    await _commit(next);
  }

  Future<void> _probePauseSupport(String id, String taskId) async {
    final supported = await asyncGuard(() => _service.canResume(taskId));
    if (supported.dataOrNull != true) return;
    await _serialized(() async {
      final current = _transfers[id];
      if (current == null || current.taskId != taskId) return;
      await _commit(current.copyWith(canPauseNatively: true));
    });
  }

  TransferModel? _modelFor(TransferTaskEvent event) {
    final meta = event.meta;
    final existing = meta != null
        ? _transfers[meta.transferId]
        : _transfers.values
              .where((transfer) => transfer.taskId == event.taskId)
              .firstOrNull;
    if (existing != null || meta == null) return existing;
    // The row was lost (e.g. storage cleared) but the task carries enough
    // metadata to rebuild it.
    return _transfers[meta.transferId] = TransferModel(
      id: meta.transferId,
      taskId: event.taskId,
      type: meta.type,
      fileName: meta.displayName,
      remoteFileName: meta.remoteName,
      status: TransferStatus.queued,
      createdAt: meta.createdAt,
      updatedAt: _clock(),
    );
  }

  /// The upload response named no file, so look the stored name up in the
  /// list. Runs outside the queue because it waits on the network.
  Future<void> _resolveRemoteNameFromList(TransferModel model) async {
    final listed = await asyncGuard(
      () async => RemoteFilesParser.parseList(await _client.getFiles()),
    );
    final files = listed.dataOrNull;
    if (files == null) return;
    final name = UploadedNameResolver.resolve(
      localName: model.fileName,
      files: files,
      uploadedAfter: model.createdAt.subtract(const Duration(minutes: 1)),
    );
    await _serialized(() async {
      final current = _transfers[model.id];
      if (current == null || current.remoteFileName == name) return;
      await _commit(current.copyWith(remoteFileName: name));
    });
  }

  /// The picker copies each file into app storage; drop the copy once the
  /// upload no longer needs it.
  void _deletePickedCopy(TransferModel model) {
    final path = model.localPath;
    if (!model.isUpload || path == null) return;
    asyncGuard(() => _service.deletePickedCopy(path)).ignore();
  }

  /// Moves completed downloads that were not finalized yet, e.g. because the
  /// app was killed between completion and the move.
  Future<void> _finalizePending() async {
    final pending = _transfers.values
        .where((transfer) => transfer.pendingFinalize)
        .toList();
    for (final model in pending) {
      await _commit(await _finalize(model));
    }
  }

  Future<TransferModel> _finalize(TransferModel model) async {
    if (!model.pendingFinalize) return model;
    final result = await asyncGuard(
      () => _service.finalizeDownload(model.fileName),
    );
    return switch (result) {
      Success(:final data) => model.copyWith(
        savedPath: data,
        pendingFinalize: false,
      ),
      Error(:final error) => model.copyWith(
        status: TransferStatus.failed,
        errorKind: TransferErrorKind.storage,
        errorMessage: error.message,
        pendingFinalize: false,
        updatedAt: _clock(),
      ),
    };
  }

  /// Applies native states that changed while no listener was attached.
  Future<void> _reconcileWithNativeRecords() async {
    final now = _clock();
    final candidates = _transfers.values.where(
      (transfer) =>
          transfer.status.isActive ||
          (transfer.isDownload && transfer.status == TransferStatus.paused),
    );
    for (final model in candidates.toList()) {
      final recorded = await _service.recordedStatus(model.taskId);
      if (recorded != null) {
        if (recorded.status != model.status) await _applyEvent(recorded);
      } else if (model.status.isActive &&
          now.difference(model.updatedAt) > _lostTaskGrace) {
        await _commit(
          model.copyWith(
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.unknown,
            errorMessage: 'Native task lost',
            updatedAt: now,
          ),
        );
      }
    }
  }

  Future<void> _delete(List<TransferModel> models) async {
    if (models.isEmpty) return;
    for (final model in models) {
      _transfers.remove(model.id);
    }
    await _dao.deleteByIds(models.map((model) => model.id));
    for (final model in models) {
      _service.deleteRecord(model.taskId).ignore();
      _deletePickedCopy(model);
      _removed.add(model.id);
    }
  }

  Future<void> _commit(TransferModel model) async {
    _transfers[model.id] = model;
    await _dao.upsert(model);
    _updates.add(model);
  }

  void _emit(TransferModel model) {
    _transfers[model.id] = model;
    _updates.add(model);
  }

  Future<TransferModel> _require(String id) async {
    await _ensureLoaded();
    final model = _transfers[id];
    if (model == null) {
      throw Failure(FailureKind.notFound, 'Unknown transfer $id');
    }
    return model;
  }

  /// Reads the token right before enqueueing, so tasks never start with a
  /// session that is already gone.
  ({String authorizationHeader}) _requireSession() {
    final session = _sessionStorage.read();
    if (session == null || session.isExpiredAt(_clock())) {
      throw const Failure(FailureKind.unauthorized, 'No valid session');
    }
    return (authorizationHeader: session.authorizationHeader);
  }

  TransferTaskMeta _metaFor(TransferModel model) => TransferTaskMeta(
    transferId: model.id,
    type: model.type,
    displayName: model.fileName,
    remoteName: model.remoteFileName,
    createdAt: model.createdAt,
  );

  String _newId() =>
      '${_clock().microsecondsSinceEpoch.toRadixString(36)}${_random.nextInt(1 << 32).toRadixString(36)}';
}
