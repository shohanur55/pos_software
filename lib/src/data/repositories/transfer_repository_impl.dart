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
import '../../domain/entities/transfer_pause_reason.dart';
import '../../domain/entities/transfer_status.dart';
import '../../domain/entities/transfer_type.dart';
import '../../domain/entities/upload_request_entity.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../../domain/services/connectivity_service.dart';
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
import '../services/transfer/upload_resume_probe.dart';
import '../services/transfer/uploaded_name_resolver.dart';

class TransferRepositoryImpl extends TransferRepository {
  TransferRepositoryImpl(
    this._service,
    this._dao,
    this._sessionStorage,
    this._client,
    this._settings,
    this._cache,
    this._connectivity,
    this._resumeProbe, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final BackgroundTransferService _service;
  final TransferDao _dao;
  final SessionStorage _sessionStorage;
  final RestClient _client;
  final SystemSettingsService _settings;
  final CacheService _cache;
  final ConnectivityService _connectivity;
  final UploadResumeProbe _resumeProbe;
  final DateTime Function() _clock;
  final Random _random = Random();

  final Map<String, TransferModel> _transfers = {};
  final StreamController<TransferEntity> _updates =
      StreamController<TransferEntity>.broadcast();
  final StreamController<String> _removed =
      StreamController<String>.broadcast();
  final StreamController<bool?> _uploadResumeSupport =
      StreamController<bool?>.broadcast();

  // Serializes mutations to _transfers so events and user actions don't interleave.
  Future<void> _queue = Future.value();

  // Shared load future so concurrent callers don't see a half-filled map.
  Future<void>? _loading;

  StreamSubscription<bool>? _connectivitySubscription;

  // Keeps parking/resuming ordered by connection changes.
  Future<void> _networkQueue = Future.value();

  // Auto-restart count per transfer.
  final Map<String, int> _autoRestarts = {};

  // Cap auto-restarts for transfers that must re-send the whole file, so a
  // flapping connection doesn't loop the same upload forever.
  static const int _autoRestartLimit = 3;

  // Grace period before a missing native task is treated as lost; a freshly
  // enqueued task may not be recorded yet.
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
  Stream<bool?> watchUploadResumeSupport() => _uploadResumeSupport.stream;

  @override
  bool? get uploadResumeSupport => _resumeProbe.cachedSupport;

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
      // Move out of the cache dir first; the OS can purge it while the upload
      // is parked or waiting to retry.
      final source = await _service.retainUploadSource(request.filePath);
      // Check resume support now so the UI can warn before a pause.
      _checkUploadResumeSupport(session, request.sizeBytes);
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
        localPath: source,
        url: Endpoints.uploadUrl,
        totalBytes: request.sizeBytes,
      );
      await _service.enqueueUpload(
        taskId: id,
        filePath: source,
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
      // Only prompts on Android 9 and below; a refusal keeps the file in
      // private storage.
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
      await _park(id, TransferPauseReason.user);
    });
  }

  // Pauses a transfer. A running download on a range-capable server pauses in
  // place (partial file and offset kept); anything else stops the native task
  // but keeps its byte count. Always succeeds.
  Future<void> _park(String id, TransferPauseReason reason) async {
    final model = _transfers[id];
    if (model == null || !model.status.canPause) return;
    final pausedInPlace =
        model.isDownload &&
        model.status == TransferStatus.running &&
        (await asyncGuard(() => _service.pauseDownload(model.taskId)))
                .dataOrNull ==
            true;
    await _serialized(() async {
      final current = _transfers[id];
      // May have finished or been replaced while the native pause was in flight.
      if (current == null ||
          current.taskId != model.taskId ||
          !current.status.canPause) {
        return;
      }
      await _commit(
        current.copyWith(
          status: TransferStatus.paused,
          pauseReason: reason,
          clearTransient: true,
          updatedAt: _clock(),
        ),
      );
    });
    if (!pausedInPlace) await _service.cancel(model.taskId);
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
      return _resumeModel(model);
    });
  }

  // Resumes a paused transfer: from its offset where possible, else from the start.
  Future<TransferModel> _resumeModel(TransferModel model) async {
    final session = _requireSession();
    // Nothing transferred yet, so just restart.
    if (model.transferredBytes <= 0) return _restart(model);
    if (model.isDownload) {
      // Refresh the auth header; a download can stay paused longer than a
      // token lives.
      if (await _service.resumeDownload(
        model.taskId,
        authorization: session.authorizationHeader,
      )) {
        final resumed = model.copyWith(
          status: TransferStatus.queued,
          clearError: true,
          clearPauseReason: true,
          updatedAt: _clock(),
        );
        await _serialized(() => _commit(resumed));
        return resumed;
      }
      return _restart(model, notice: TransferErrorKind.resumeFailed);
    }
    final offset = await _confirmedUploadOffset(model, session);
    final total = model.totalBytes;
    if (offset != null && total != null && offset >= total) {
      // Server already has the whole file; re-sending would duplicate it.
      return _completeWithoutResending(model);
    }
    if (offset == null || offset <= 0) {
      return _restart(model, notice: TransferErrorKind.resumeNotSupported);
    }
    return _restart(model, resumeFromByte: offset);
  }

  // Marks an upload complete when the server already holds every byte, and
  // resolves the stored name from the file list.
  Future<TransferModel> _completeWithoutResending(TransferModel model) async {
    final completed = model.copyWith(
      status: TransferStatus.completed,
      progress: 1,
      transferredBytes: model.totalBytes,
      clearTransient: true,
      clearError: true,
      clearPauseReason: true,
      updatedAt: _clock(),
    );
    await _serialized(() => _commit(completed));
    _resolveRemoteNameFromList(completed).ignore();
    _deletePickedCopy(completed);
    return completed;
  }

  // Checks in the background whether the endpoint supports resumable uploads.
  void _checkUploadResumeSupport(
    ({String authorizationHeader}) session,
    int totalBytes,
  ) {
    if (_resumeProbe.cachedSupport != null) return;
    asyncGuard(
      () => _resumeProbe.ensureChecked(
        totalBytes: totalBytes,
        authorization: session.authorizationHeader,
      ),
    ).then((result) => _publishUploadResumeSupport()).ignore();
  }

  void _publishUploadResumeSupport() {
    if (_uploadResumeSupport.isClosed) return;
    _uploadResumeSupport.add(_resumeProbe.cachedSupport);
  }

  // Asks the server how many bytes of this upload it holds; any failure means none.
  Future<int?> _confirmedUploadOffset(
    TransferModel model,
    ({String authorizationHeader}) session,
  ) async {
    final total = model.totalBytes;
    if (total == null || total <= 0) return null;
    final probed = await asyncGuard(
      () => _resumeProbe.confirmedBytes(
        uploadId: model.id,
        totalBytes: total,
        transferredBytes: model.transferredBytes,
        authorization: session.authorizationHeader,
      ),
    );
    _publishUploadResumeSupport();
    return probed.dataOrNull;
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
      await _pruneUploadSources();
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

  // Releases the connectivity subscription and update streams. Mainly used by tests.
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    _autoRestarts.clear();
    _connectivitySubscription = null;
    await _updates.close();
    await _removed.close();
    await _uploadResumeSupport.close();
  }

  @override
  Failure mapException(Object error, StackTrace stackTrace) {
    if (error is FileSystemException) {
      return Failure(FailureKind.storage, error.message);
    }
    return NetworkFailureMapper.map(error);
  }

  // A failed load (locked or corrupt db) isn't cached, so the next call retries.
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
    // Subscribe only after history is loaded so an event can't recreate a
    // pending row. Failures are logged by the queue; nobody awaits handling.
    _service.events.listen(
      (event) => _serialized(() => _applyEvent(event)).ignore(),
    );
    // Own queue, not _serialized: the handlers serialize their own writes and
    // nesting would deadlock. Ordering still matters so a reconnect can't run
    // before parking finishes.
    _connectivitySubscription = _connectivity.watchOnline().listen((online) {
      _networkQueue = _networkQueue
          .then((_) => online ? _resumeAfterNetwork() : _pauseForNetwork())
          .catchError((Object error, StackTrace stackTrace) {
            logger.e(
              'Network change handling failed',
              error: error,
              stackTrace: stackTrace,
            );
          });
    });
  }

  // Parks running transfers when the server becomes unreachable, keeping their
  // bytes and recording why. Queued transfers are left for the OS to hold.
  Future<void> _pauseForNetwork() async {
    final running = _transfers.values
        .where(
          (transfer) =>
              transfer.status == TransferStatus.running ||
              transfer.status == TransferStatus.waitingToRetry,
        )
        .toList();
    for (final model in running) {
      await asyncGuard(() => _park(model.id, TransferPauseReason.noNetwork));
    }
  }

  // Resumes network-parked transfers, oldest first. User-paused ones are left alone.
  Future<void> _resumeAfterNetwork() async {
    final parked =
        _transfers.values
            .where((transfer) => transfer.isWaitingForNetwork)
            .toList()
          ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    for (final model in parked) {
      if (!model.resumesWhereItStopped) {
        final used = _autoRestarts[model.id] ?? 0;
        if (used >= _autoRestartLimit) continue;
        _autoRestarts[model.id] = used + 1;
      }
      // A resume can still fail (expired session, missing source); reported on
      // the row, and must not strand the rest.
      await asyncGuard(() => _resumeModel(model));
    }
  }

  Future<void> _serialized(Future<void> Function() action) {
    final next = _queue.then((_) => action());
    // Keep the queue alive after a failure; the caller still sees the error.
    _queue = next.catchError((Object error, StackTrace stackTrace) {
      logger.e('Transfer update failed', error: error, stackTrace: stackTrace);
    });
    return next;
  }

  // Stores a newly enqueued transfer; an event may have created the row from
  // task metadata already, in which case its status wins.
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

  // Runs the transfer again on a fresh task and token. With resumeFromByte set,
  // an upload picks up at that offset instead of restarting, keeping its progress.
  Future<TransferModel> _restart(
    TransferModel model, {
    TransferErrorKind? notice,
    int resumeFromByte = 0,
  }) async {
    final session = _requireSession();
    final oldTaskId = model.taskId;
    final now = _clock();
    final restarted = resumeFromByte > 0
        ? model.resumedWith(_newId(), resumeFromByte, now)
        : model.restartedWith(_newId(), now, notice: notice);
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
              resumeFromByte: resumeFromByte,
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

  // A restarted row must not stay queued with no native task behind it.
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
    // User-initiated states are final: a paused upload's task was canceled on
    // purpose, and a canceled row stays canceled.
    if (model.status == TransferStatus.canceled) return;
    if (model.isUpload && model.status == TransferStatus.paused) return;
    // Parking cancels the native task; ignore that cancellation for a paused row.
    if (model.status == TransferStatus.paused &&
        event is TransferStatusEvent &&
        event.status == TransferStatus.canceled) {
      return;
    }

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
    // The native side fails a download whose pause couldn't keep its place
    // (server refused the range, or the partial file went missing). Keep it
    // paused (it restarts on resume) instead of showing Failed for a
    // deliberate pause.
    if (model.isDownload &&
        model.status == TransferStatus.paused &&
        event.status == TransferStatus.failed &&
        event.errorKind == TransferErrorKind.resumeFailed) {
      await _commit(
        model.copyWith(canPauseNatively: false, updatedAt: _clock()),
      );
      return;
    }
    var next = model.applyStatus(event, _clock());
    // A download reports paused only after its partial file and offset are
    // written, so resuming is guaranteed to carry on from there.
    if (event.status == TransferStatus.paused && model.isDownload) {
      next = next.copyWith(canPauseNatively: true);
    }
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

  // Upload response named no file; look the name up in the list. Runs outside
  // the queue because it waits on the network.
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

  // Drops the picker's copy once the upload no longer needs it.
  void _deletePickedCopy(TransferModel model) {
    final path = model.localPath;
    if (!model.isUpload || path == null) return;
    asyncGuard(() => _service.deletePickedCopy(path)).ignore();
  }

  // Drops upload sources no transfer refers to any more, e.g. ones stranded by
  // a crash between the move and the database write.
  Future<void> _pruneUploadSources() async {
    final inUse = _transfers.values
        .where(
          (transfer) =>
              transfer.isUpload && transfer.status != TransferStatus.completed,
        )
        .map((transfer) => transfer.localPath)
        .whereType<String>();
    await asyncGuard(() => _service.pruneUploadSources(inUse));
  }

  // Moves completed downloads not finalized yet, e.g. app killed mid-move.
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
      _autoRestarts.remove(model.id);
    }
    await _dao.deleteByIds(models.map((model) => model.id));
    for (final model in models) {
      _service.deleteRecord(model.taskId).ignore();
      _deletePickedCopy(model);
      _removed.add(model.id);
    }
  }

  Future<void> _commit(TransferModel model) async {
    // Reset the auto-restart budget once completed.
    if (model.status == TransferStatus.completed) {
      _autoRestarts.remove(model.id);
    }
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

  // Reads the token right before enqueueing so tasks never start with a stale session.
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
