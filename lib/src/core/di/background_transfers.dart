import '../../data/services/transfer/background_transfer_service.dart';
import '../../data/services/transfer/transfer_notification_texts.dart';
import '../constants/app_strings.dart';
import 'dependency_injection.dart';

/// Configures the transfer plugin with its notification copy. Tokens in
/// braces are filled in by the plugin.
Future<void> initializeBackgroundTransfers() async {
  const name = '{displayName}';
  await sl<BackgroundTransferService>().init(
    TransferNotificationTexts(
      uploadRunningTitle: AppStrings.notificationUploadingTitle(name),
      uploadPausedTitle: AppStrings.notificationUploadPausedTitle,
      uploadCompleteTitle: AppStrings.notificationUploadCompleteTitle,
      uploadCompleteBody: AppStrings.notificationUploadCompleteBody(name),
      uploadErrorTitle: AppStrings.notificationUploadFailedTitle,
      uploadErrorBody: AppStrings.notificationUploadFailedBody(name),
      downloadRunningTitle: AppStrings.notificationDownloadingTitle(name),
      downloadPausedTitle: AppStrings.notificationDownloadPausedTitle,
      downloadCompleteTitle: AppStrings.notificationDownloadCompleteTitle,
      downloadCompleteBody: AppStrings.notificationDownloadCompleteBody(name),
      downloadErrorTitle: AppStrings.notificationDownloadFailedTitle,
      downloadErrorBody: AppStrings.notificationDownloadFailedBody(name),
      runningBody: AppStrings.notificationRunningBody(
        '{progress}',
        '{networkSpeed}',
        '{timeRemaining}',
      ),
    ),
  );
}
