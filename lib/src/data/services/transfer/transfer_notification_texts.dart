/// Notification copy handed to the native side, which renders it without a
/// BuildContext.
class TransferNotificationTexts {
  const TransferNotificationTexts({
    required this.uploadRunningTitle,
    required this.uploadPausedTitle,
    required this.uploadCompleteTitle,
    required this.uploadCompleteBody,
    required this.uploadErrorTitle,
    required this.uploadErrorBody,
    required this.downloadRunningTitle,
    required this.downloadPausedTitle,
    required this.downloadCompleteTitle,
    required this.downloadCompleteBody,
    required this.downloadErrorTitle,
    required this.downloadErrorBody,
    required this.runningBody,
  });

  final String uploadRunningTitle;
  final String uploadPausedTitle;
  final String uploadCompleteTitle;
  final String uploadCompleteBody;
  final String uploadErrorTitle;
  final String uploadErrorBody;
  final String downloadRunningTitle;
  final String downloadPausedTitle;
  final String downloadCompleteTitle;
  final String downloadCompleteBody;
  final String downloadErrorTitle;
  final String downloadErrorBody;
  final String runningBody;
}
