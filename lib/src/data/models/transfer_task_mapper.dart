import 'package:background_downloader/background_downloader.dart';

import '../../domain/entities/transfer_error_kind.dart';
import '../../domain/entities/transfer_status.dart';
import '../../domain/entities/transfer_type.dart';
import 'transfer_events.dart';
import 'transfer_task_meta.dart';

/// Translates `background_downloader` types into domain vocabulary.
abstract final class TransferTaskMapper {
  static const double _bytesPerMegabyte = 1000 * 1000;

  static TransferStatus status(TaskStatus status) => switch (status) {
    TaskStatus.enqueued => TransferStatus.queued,
    TaskStatus.running => TransferStatus.running,
    TaskStatus.complete => TransferStatus.completed,
    TaskStatus.notFound || TaskStatus.failed => TransferStatus.failed,
    TaskStatus.canceled => TransferStatus.canceled,
    TaskStatus.waitingToRetry => TransferStatus.waitingToRetry,
    TaskStatus.paused => TransferStatus.paused,
  };

  /// Maps the package's negative progress sentinels to a status, or `null`
  /// for a regular 0..1 progress value.
  static TransferStatus? statusFromProgress(double progress) {
    if (progress >= 0) return null;
    if (progress == progressFailed) return TransferStatus.failed;
    if (progress == progressCanceled) return TransferStatus.canceled;
    if (progress == progressNotFound) return TransferStatus.failed;
    if (progress == progressWaitingToRetry) {
      return TransferStatus.waitingToRetry;
    }
    if (progress == progressPaused) return TransferStatus.paused;
    return TransferStatus.failed;
  }

  static double clampProgress(double progress) =>
      progress < 0 ? 0 : (progress > 1 ? 1 : progress);

  static TransferErrorKind? errorKind(
    TaskStatus status,
    TaskException? exception,
    TransferType type,
  ) {
    if (status == TaskStatus.notFound) return TransferErrorKind.notFound;
    if (status != TaskStatus.failed) return null;
    return switch (exception) {
      TaskHttpException(:final httpResponseCode) => httpErrorKind(
        httpResponseCode,
      ),
      TaskConnectionException() => TransferErrorKind.network,
      TaskResumeException() => TransferErrorKind.resumeFailed,
      TaskFileSystemException() =>
        type == TransferType.upload
            ? TransferErrorKind.invalidFile
            : TransferErrorKind.storage,
      _ => TransferErrorKind.unknown,
    };
  }

  static TransferErrorKind httpErrorKind(int code) => switch (code) {
    401 || 403 => TransferErrorKind.unauthorized,
    404 => TransferErrorKind.notFound,
    413 => TransferErrorKind.fileTooLarge,
    400 || 415 || 422 => TransferErrorKind.invalidFile,
    416 => TransferErrorKind.resumeFailed,
    >= 500 => TransferErrorKind.server,
    _ => TransferErrorKind.unknown,
  };

  static TransferStatusEvent fromStatusUpdate(TaskStatusUpdate update) {
    final meta = TransferTaskMeta.tryDecode(update.task.metaData);
    final type =
        meta?.type ??
        (update.task is UploadTask
            ? TransferType.upload
            : TransferType.download);
    return TransferStatusEvent(
      update.task.taskId,
      meta,
      status: status(update.status),
      errorKind: errorKind(update.status, update.exception, type),
      errorMessage: update.exception?.description,
      responseBody: update.responseBody,
    );
  }

  /// Returns a status event for sentinel values, otherwise a progress event.
  static TransferTaskEvent fromProgressUpdate(TaskProgressUpdate update) {
    final meta = TransferTaskMeta.tryDecode(update.task.metaData);
    final sentinel = statusFromProgress(update.progress);
    if (sentinel != null) {
      return TransferStatusEvent(update.task.taskId, meta, status: sentinel);
    }
    return TransferProgressEvent(
      update.task.taskId,
      meta,
      progress: clampProgress(update.progress),
      expectedBytes: update.hasExpectedFileSize
          ? update.expectedFileSize
          : null,
      speedBytesPerSecond: update.hasNetworkSpeed
          ? update.networkSpeed * _bytesPerMegabyte
          : null,
      timeRemaining: update.hasTimeRemaining ? update.timeRemaining : null,
    );
  }

  static TransferStatusEvent fromRecord(TaskRecord record) {
    final meta = TransferTaskMeta.tryDecode(record.task.metaData);
    final type =
        meta?.type ??
        (record.task is UploadTask
            ? TransferType.upload
            : TransferType.download);
    return TransferStatusEvent(
      record.taskId,
      meta,
      status: status(record.status),
      errorKind: errorKind(record.status, record.exception, type),
      errorMessage: record.exception?.description,
    );
  }
}
