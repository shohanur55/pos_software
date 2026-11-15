import '../../core/base/failure.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/byte_formatter.dart';
import '../../core/utils/duration_formatter.dart';
import '../../domain/entities/transfer_entity.dart';
import '../../domain/entities/transfer_error_kind.dart';
import '../../domain/entities/transfer_status.dart';
import '../../domain/entities/upload_validation_error.dart';

/// Maps domain values to user-facing copy. Technical details never leak.
abstract final class UiMessages {
  static String failureMessage(FailureKind? kind) => switch (kind) {
    FailureKind.network => AppStrings.errorNetwork,
    FailureKind.unauthorized => AppStrings.errorUnauthorized,
    FailureKind.invalidCredentials => AppStrings.errorInvalidCredentials,
    FailureKind.notFound => AppStrings.errorFileGone,
    FailureKind.server => AppStrings.errorServer,
    FailureKind.fileTooLarge => AppStrings.errorFileTooLarge,
    FailureKind.invalidFile => AppStrings.errorUnreadableFile,
    FailureKind.storage => AppStrings.errorStorage,
    FailureKind.resumeFailed => AppStrings.errorResumeFailed,
    FailureKind.alreadyInProgress => AppStrings.errorAlreadyDownloading,
    FailureKind.notAllowed => AppStrings.errorNotAllowed,
    FailureKind.cannotOpen ||
    FailureKind.invalidResponse ||
    FailureKind.unknown ||
    null => AppStrings.errorUnknown,
  };

  static String transferErrorMessage(TransferErrorKind? kind) => switch (kind) {
    TransferErrorKind.network => AppStrings.errorNetwork,
    TransferErrorKind.unauthorized => AppStrings.errorUnauthorized,
    TransferErrorKind.fileTooLarge => AppStrings.errorFileTooLarge,
    TransferErrorKind.invalidFile => AppStrings.errorRejectedFile,
    TransferErrorKind.notFound => AppStrings.errorFileGone,
    TransferErrorKind.server => AppStrings.errorServer,
    TransferErrorKind.storage => AppStrings.errorStorage,
    TransferErrorKind.resumeFailed => AppStrings.errorResumeFailed,
    TransferErrorKind.resumeNotSupported => AppStrings.errorResumeNotSupported,
    TransferErrorKind.unknown || null => AppStrings.errorUnknown,
  };

  static String validationMessage(UploadValidationError error) =>
      switch (error) {
        UploadValidationError.missing ||
        UploadValidationError.unreadable => AppStrings.validationUnreadable,
        UploadValidationError.empty => AppStrings.validationEmpty,
        UploadValidationError.tooLarge => AppStrings.validationTooLarge,
        UploadValidationError.unsupportedType =>
          AppStrings.validationUnsupported,
      };

  static String statusLabel(TransferEntity transfer) =>
      switch (transfer.status) {
        TransferStatus.queued => AppStrings.statusQueued,
        TransferStatus.running =>
          transfer.isUpload
              ? AppStrings.statusUploading
              : AppStrings.statusDownloading,
        TransferStatus.paused =>
          transfer.isWaitingForNetwork
              ? AppStrings.statusPausedNoNetwork
              : AppStrings.statusPaused,
        TransferStatus.waitingToRetry => AppStrings.statusWaitingToRetry,
        TransferStatus.completed => AppStrings.statusCompleted,
        TransferStatus.failed => AppStrings.statusFailed,
        TransferStatus.canceled => AppStrings.statusCanceled,
      };

  /// What a paused transfer will do when it starts again, or `null` when it
  /// is not paused.
  ///
  /// Stating this while the transfer sits still is the whole point: an
  /// operator deciding whether to wait for the shop Wi-Fi or walk the terminal
  /// to a different one needs to know whether the 400 MB already sent survives
  /// the wait.
  static String? pausedDetail(TransferEntity transfer) {
    if (transfer.status != TransferStatus.paused) return null;
    final keepsPlace = transfer.resumesWhereItStopped;
    final position = ByteFormatter.format(transfer.transferredBytes);
    if (transfer.isWaitingForNetwork) {
      return keepsPlace
          ? AppStrings.offlineResumesFrom(position)
          : AppStrings.offlineStartsOver;
    }
    return keepsPlace
        ? AppStrings.pausedResumesFrom(position)
        : AppStrings.pausedStartsOver;
  }

  static String timeLeft(Duration duration) {
    final remaining = DurationFormatter.remaining(duration);
    return switch (remaining.unit) {
      RemainingUnit.seconds => AppStrings.timeLeftSeconds(remaining.value),
      RemainingUnit.minutes => AppStrings.timeLeftMinutes(remaining.value),
      RemainingUnit.hours => AppStrings.timeLeftHours(remaining.value),
    };
  }

  static String relativeTime(DateTime time, DateTime now) {
    final elapsed = now.difference(time);
    if (elapsed.inMinutes < 1) return AppStrings.relativeJustNow;
    if (elapsed.inHours < 1) {
      return AppStrings.relativeMinutes(elapsed.inMinutes);
    }
    if (elapsed.inDays < 1) return AppStrings.relativeHours(elapsed.inHours);
    return AppStrings.relativeDays(elapsed.inDays);
  }

  static String percent(double progress) => '${(progress * 100).round()}%';
}
