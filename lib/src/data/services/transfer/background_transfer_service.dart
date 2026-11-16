import 'dart:async';
import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

import '../../../core/base/failure.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/transfer_constants.dart';
import '../../../core/utils/app_logger.dart';
import '../../../domain/entities/notification_permission_status.dart';
import '../../../domain/entities/transfer_notification_tap_entity.dart';
import '../../models/transfer_events.dart';
import '../../models/transfer_task_mapper.dart';
import '../../models/transfer_task_meta.dart';
import '../network/endpoints.dart';
import 'progress_throttle.dart';
import 'transfer_notification_texts.dart';

enum OpenFileOutcome { opened, notFound, noApp }

/// The only class that talks to `background_downloader`.
///
/// Uses single-subscription streams so events the plugin replays during [init]
/// (transfers finished while the app was dead, a cold-start notification tap)
/// buffer until the repository starts listening.
class BackgroundTransferService {
  BackgroundTransferService({
    FileDownloader? downloader,
    ProgressThrottle? throttle,
  }) : _downloader = downloader ?? FileDownloader(),
       _throttle =
           throttle ?? ProgressThrottle(TransferConstants.progressInterval);

  final FileDownloader _downloader;
  final ProgressThrottle _throttle;
  final StreamController<TransferTaskEvent> _events =
      StreamController<TransferTaskEvent>();
  final StreamController<TransferNotificationTapEntity> _taps =
      StreamController<TransferNotificationTapEntity>();
  bool _initialized = false;

  Stream<TransferTaskEvent> get events => _events.stream;

  Stream<TransferNotificationTapEntity> get notificationTaps => _taps.stream;

  // Configures the plugin, registers callbacks and replays background events.
  // Must run in main() before runApp so cold-start taps are captured.
  Future<void> init(TransferNotificationTexts texts) async {
    if (_initialized) return;
    _initialized = true;

    await _downloader.configure(
      globalConfig: [
        (Config.requestTimeout, const Duration(seconds: 60)),
        (Config.checkAvailableSpace, 50),
      ],
      androidConfig: [
        // Foreground mode lifts WorkManager's 9-minute limit for big files.
        (Config.runInForeground, Config.always),
        // The cache dir can be purged mid-transfer, which breaks resume.
        (Config.useCacheDir, Config.never),
      ],
    );
    _configureNotifications(texts);
    for (final group in const [
      TransferConstants.uploadGroup,
      TransferConstants.downloadGroup,
    ]) {
      _downloader.registerCallbacks(
        group: group,
        taskStatusCallback: _onStatus,
        taskProgressCallback: _onProgress,
        taskNotificationTapCallback: _onNotificationTap,
      );
    }
    await _downloader.start(autoCleanDatabase: true);
  }

  Future<void> resumeFromBackground() => _downloader.resumeFromBackground();

  // Starts an upload. A fresh one is a multipart POST; a resumed one sends only
  // the bytes from resumeFromByte onward as a raw body, with the offset in
  // Range (plugin seeks the file) and Content-Range (server places them). The
  // caller only passes an offset after the probe confirmed the server accepts it.
  Future<void> enqueueUpload({
    required String taskId,
    required String filePath,
    required String authorization,
    required TransferTaskMeta meta,
    int resumeFromByte = 0,
  }) async {
    final (baseDirectory, directory, filename) = await Task.split(
      filePath: filePath,
    );
    final resuming = resumeFromByte > 0;
    final totalBytes = resuming ? await File(filePath).length() : 0;
    final task = UploadTask(
      taskId: taskId,
      url: Endpoints.uploadUrl,
      filename: filename,
      baseDirectory: baseDirectory,
      directory: directory,
      fileField: TransferConstants.uploadFileField,
      post: resuming ? 'binary' : null,
      headers: {
        'Authorization': authorization,
        if (resuming) ...{
          'Range': 'bytes=$resumeFromByte-${totalBytes - 1}',
          'Content-Range':
              'bytes $resumeFromByte-${totalBytes - 1}/$totalBytes',
          Endpoints.uploadIdHeader: meta.transferId,
        },
      },
      group: TransferConstants.uploadGroup,
      updates: Updates.statusAndProgress,
      retries: TransferConstants.retries,
      metaData: meta.encode(),
      displayName: meta.displayName,
    );
    await _enqueue(task);
  }

  Future<void> enqueueDownload({
    required String taskId,
    required String url,
    required String fileName,
    required String authorization,
    required TransferTaskMeta meta,
  }) async {
    final task = DownloadTask(
      taskId: taskId,
      url: url,
      filename: fileName,
      baseDirectory: _downloadBaseDirectory,
      directory: _downloadDirectory,
      headers: {'Authorization': authorization},
      group: TransferConstants.downloadGroup,
      updates: Updates.statusAndProgress,
      retries: TransferConstants.retries,
      allowPause: true,
      metaData: meta.encode(),
      displayName: meta.displayName,
    );
    await _enqueue(task);
  }

  Future<bool> pauseDownload(String taskId) async {
    final task = await _taskFor(taskId);
    return task is DownloadTask && await _downloader.pause(task);
  }

  // Continues a paused download from where it stopped. authorization replaces
  // the task's original header, since a download can stay paused longer than a
  // token lives and the stale header would collect a 401. Returns false when
  // the plugin cannot resume (partial file gone, server stopped accepting ranges).
  Future<bool> resumeDownload(String taskId, {String? authorization}) async {
    final task = await _taskFor(taskId);
    if (task is! DownloadTask) return false;
    final refreshed = authorization == null
        ? task
        : task.copyWith(
            headers: {...task.headers, 'Authorization': authorization},
          );
    return _downloader.resume(refreshed);
  }

  // Whether the server accepted range requests for a running download.
  Future<bool> canResume(String taskId) async {
    final task = await _taskFor(taskId);
    return task is DownloadTask && await _downloader.taskCanResume(task);
  }

  Future<void> cancel(String taskId) async {
    await _downloader.cancelTaskWithId(taskId);
    _throttle.forget(taskId);
  }

  Future<void> deleteRecord(String taskId) =>
      _downloader.database.deleteRecordWithId(taskId);

  // Last known native state of a task, or null if the plugin forgot it.
  Future<TransferStatusEvent?> recordedStatus(String taskId) async {
    final record = await _downloader.database.recordForId(taskId);
    return record == null ? null : TransferTaskMapper.fromRecord(record);
  }

  Future<String> downloadPath(String fileName) async {
    final base = await Task.baseDirectoryPath(_downloadBaseDirectory);
    return p.join(base, _downloadDirectory, fileName);
  }

  Future<List<String>> existingDownloadNames() async {
    final directory = Directory(p.dirname(await downloadPath('_')));
    if (!await directory.exists()) return const [];
    return directory
        .list()
        .where((entity) => entity is File)
        .map((entity) => p.basename(entity.path))
        .toList();
  }

  // Moves a completed download to its user-visible location: Android public
  // Downloads/<AppName> via MediaStore, iOS already in Documents. Idempotent:
  // if the process died after an earlier move, the file is found in shared
  // storage rather than reported missing.
  Future<String> finalizeDownload(String fileName) async {
    final source = await downloadPath(fileName);
    final sourceExists = await File(source).exists();
    if (!Platform.isAndroid) {
      if (sourceExists) return source;
      throw Failure(
        FailureKind.storage,
        'Downloaded file is missing: $fileName',
      );
    }
    if (!sourceExists) {
      final moved = await _downloader.pathInSharedStorage(
        source,
        SharedStorage.downloads,
        directory: AppConstants.downloadFolderName,
      );
      // Before Android 10 the plugin returns the expected path without checking
      // the file is there.
      final found =
          moved != null &&
          (await _usesScopedStorage() || await File(moved).exists());
      if (found) return moved;
      throw Failure(
        FailureKind.storage,
        'Downloaded file is missing: $fileName',
      );
    }
    final moved = await _downloader.moveFileToSharedStorage(
      source,
      SharedStorage.downloads,
      directory: AppConstants.downloadFolderName,
      mimeType: lookupMimeType(fileName),
    );
    // The move is refused when the legacy storage permission was denied
    // (Android 9 and below). The download succeeded, so keep it in private
    // storage where it can still be opened from the app.
    return moved ?? source;
  }

  // Android 9 and below need the legacy storage permission to save into public
  // Downloads. Newer versions report it as granted.
  Future<void> ensureSharedStoragePermission() async {
    if (!Platform.isAndroid) return;
    final permissions = _downloader.permissions;
    final status = await permissions.status(
      PermissionType.androidSharedStorage,
    );
    if (status != PermissionStatus.granted) {
      await permissions.request(PermissionType.androidSharedStorage);
    }
  }

  // Opens a finished download with whatever app handles its type.
  Future<OpenFileOutcome> openDownload({
    required String fileName,
    required String? savedPath,
  }) async {
    final target = await _openTarget(fileName, savedPath);
    if (target == null) return OpenFileOutcome.notFound;
    final opened = await _downloader.openFile(
      filePath: target,
      mimeType: lookupMimeType(fileName),
    );
    return opened ? OpenFileOutcome.opened : OpenFileOutcome.noApp;
  }

  // Moves the picker's copy out of the cache dir and returns the new path. The
  // picker writes into the app cache, which Android can purge while an upload
  // waits (parked for Wi-Fi, or failed until retried), losing the source. Both
  // dirs are in the app container, so this is a rename (no second copy); the
  // fallbacks cover the case where that doesn't hold. A path outside the
  // sandbox belongs to the user and is returned untouched.
  Future<String> retainUploadSource(String pickedPath) async {
    final source = File(pickedPath);
    if (!await _isAppOwnedCopy(pickedPath) || !await source.exists()) {
      return pickedPath;
    }
    final directory = Directory(await _uploadSourceDirectory());
    if (p.equals(p.dirname(pickedPath), directory.path)) return pickedPath;
    await directory.create(recursive: true);
    // Stamp the name so two uploads of the same file don't collide.
    final stamp = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final target = p.join(directory.path, '${stamp}_${p.basename(pickedPath)}');
    try {
      await source.rename(target);
      return target;
    } on FileSystemException {
      try {
        await source.copy(target);
        await source.delete();
        return target;
      } on FileSystemException catch (error) {
        // A cache copy that might vanish still beats refusing the upload.
        logger.w('Could not retain upload source: ${error.message}');
        return pickedPath;
      }
    }
  }

  // Deletes upload-folder files no transfer refers to any more, e.g. stranded
  // when the app died between the move and the row being written.
  Future<void> pruneUploadSources(Iterable<String> inUse) async {
    final directory = Directory(await _uploadSourceDirectory());
    if (!await directory.exists()) return;
    final keep = inUse.toSet();
    await for (final entity in directory.list()) {
      if (entity is File && !keep.contains(entity.path)) {
        await entity.delete();
      }
    }
  }

  // Deletes the copy made for an upload. Files outside app storage are never touched.
  Future<void> deletePickedCopy(String path) async {
    if (!await _isAppOwnedCopy(path)) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  Future<bool> _isAppOwnedCopy(String path) async {
    final temporary = await Task.baseDirectoryPath(BaseDirectory.temporary);
    return p.isWithin(temporary, path) ||
        p.isWithin(Directory.systemTemp.path, path) ||
        p.isWithin(await _uploadSourceDirectory(), path);
  }

  Future<String> _uploadSourceDirectory() async => p.join(
    await Task.baseDirectoryPath(BaseDirectory.applicationSupport),
    AppConstants.uploadSourceFolderName,
  );

  Future<String?> _openTarget(String fileName, String? savedPath) async {
    if (Platform.isIOS) {
      // The app container path changes between launches, so a stored absolute
      // path can't be trusted; rebuild it.
      final path = await downloadPath(fileName);
      return await File(path).exists() ? path : null;
    }
    if (savedPath == null) return null;
    final private = await Task.baseDirectoryPath(_downloadBaseDirectory);
    if (Platform.isAndroid &&
        await _usesScopedStorage() &&
        !p.isWithin(private, savedPath)) {
      // With scoped storage, shared files are addressed by content URI.
      final uri = await _downloader.uri.pathInSharedStorage(
        Uri.file(savedPath),
        SharedStorage.downloads,
        directory: AppConstants.downloadFolderName,
      );
      return uri?.toString();
    }
    return await File(savedPath).exists() ? savedPath : null;
  }

  // Android 10 (API 29) introduced scoped storage and MediaStore downloads.
  Future<bool> _usesScopedStorage() async {
    final sdk = int.tryParse(await _downloader.platformVersion()) ?? 0;
    return sdk >= 29;
  }

  Future<NotificationPermissionStatus> notificationPermission({
    required bool alreadyAsked,
  }) async {
    final status = await _downloader.permissions.status(
      PermissionType.notifications,
    );
    return _mapPermission(status, alreadyAsked: alreadyAsked);
  }

  Future<NotificationPermissionStatus> requestNotificationPermission() async {
    final status = await _downloader.permissions.request(
      PermissionType.notifications,
    );
    return _mapPermission(status, alreadyAsked: true);
  }

  NotificationPermissionStatus _mapPermission(
    PermissionStatus status, {
    required bool alreadyAsked,
  }) {
    return switch (status) {
      PermissionStatus.granted ||
      PermissionStatus.partial => NotificationPermissionStatus.granted,
      PermissionStatus.undetermined =>
        NotificationPermissionStatus.notRequested,
      _ =>
        alreadyAsked
            ? NotificationPermissionStatus.denied
            : NotificationPermissionStatus.notRequested,
    };
  }

  // Android cannot open files in app documents, so downloads land in support
  // storage and are moved out on completion. iOS keeps them in Documents.
  BaseDirectory get _downloadBaseDirectory => Platform.isIOS
      ? BaseDirectory.applicationDocuments
      : BaseDirectory.applicationSupport;

  String get _downloadDirectory =>
      Platform.isIOS ? 'Downloads' : AppConstants.transferFolderName;

  Future<void> _enqueue(Task task) async {
    final enqueued = await _downloader.enqueue(task);
    if (!enqueued) {
      throw Failure(
        FailureKind.unknown,
        'Could not enqueue task ${task.taskId}',
      );
    }
  }

  Future<Task?> _taskFor(String taskId) async {
    return await _downloader.taskForId(taskId) ??
        (await _downloader.database.recordForId(taskId))?.task;
  }

  void _onStatus(TaskStatusUpdate update) {
    if (update.status.isFinalState) _throttle.forget(update.task.taskId);
    final event = TransferTaskMapper.fromStatusUpdate(update);
    if (event.errorMessage != null) {
      logger.w(
        'Transfer ${update.task.taskId} ${update.status.name}: ${event.errorMessage}',
      );
    }
    _events.add(event);
  }

  void _onProgress(TaskProgressUpdate update) {
    final event = TransferTaskMapper.fromProgressUpdate(update);
    if (event is TransferProgressEvent &&
        !_throttle.shouldEmit(update.task.taskId, event.progress)) {
      return;
    }
    _events.add(event);
  }

  void _onNotificationTap(Task task, NotificationType type) {
    final meta = TransferTaskMeta.tryDecode(task.metaData);
    if (meta == null) return;
    _taps.add(
      TransferNotificationTapEntity(
        transferId: meta.transferId,
        type: meta.type,
        isCompleted: type == NotificationType.complete,
      ),
    );
  }

  void _configureNotifications(TransferNotificationTexts texts) {
    _downloader
      ..configureNotificationForGroup(
        TransferConstants.uploadGroup,
        running: TaskNotification(texts.uploadRunningTitle, texts.runningBody),
        paused: TaskNotification(texts.uploadPausedTitle, _displayNameToken),
        complete: TaskNotification(
          texts.uploadCompleteTitle,
          texts.uploadCompleteBody,
        ),
        error: TaskNotification(texts.uploadErrorTitle, texts.uploadErrorBody),
        progressBar: true,
      )
      ..configureNotificationForGroup(
        TransferConstants.downloadGroup,
        running: TaskNotification(
          texts.downloadRunningTitle,
          texts.runningBody,
        ),
        paused: TaskNotification(texts.downloadPausedTitle, _displayNameToken),
        complete: TaskNotification(
          texts.downloadCompleteTitle,
          texts.downloadCompleteBody,
        ),
        error: TaskNotification(
          texts.downloadErrorTitle,
          texts.downloadErrorBody,
        ),
        progressBar: true,
      );
  }

  static const String _displayNameToken = '{displayName}';
}
