/// Every user-visible string in the app, in one place.
abstract final class AppStrings {
  static const String appName = 'POS Software';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String pause = 'Pause';
  static const String resume = 'Resume';
  static const String remove = 'Remove';
  static const String open = 'Open';
  static const String delete = 'Delete';
  static const String dismiss = 'Dismiss';
  static const String logout = 'Log out';
  static const String openSettings = 'Open settings';
  static const String viewTransfers = 'View transfers';
  static const String view = 'View';
  static const String notNow = 'Not now';
  static const String allow = 'Allow';
  static const String moreOptions = 'More options';
  static const String loginTitle = 'Welcome back';
  static const String loginSubtitle = 'Sign in to manage file transfers';
  static const String usernameLabel = 'Username';
  static const String passwordLabel = 'Password';
  static const String usernameRequired = 'Enter your username';
  static const String passwordRequired = 'Enter your password';
  static const String showPassword = 'Show password';
  static const String hidePassword = 'Hide password';
  static const String loginButton = 'Log in';
  static const String registerPrompt = 'New to POS Software?';
  static const String registerCta = 'Create an account';
  static const String openPortal = 'Open the sign-up portal';
  static const String signupTitle = 'Create account';
  static const String backToLogin = 'Back to login';
  static const String reload = 'Reload';
  static const String signupLoadFailedTitle = 'Can\'t load the portal';
  static const String signupLoadFailedBody =
      'Check your connection and try again.';
  static String errorCannotOpenPortal(String address) =>
      'Couldn\'t open the sign-up portal. Visit $address in your browser instead.';
  static const String splashTagline = 'Fast file transfers at the counter';
  static const String sessionExpired =
      'Your session has expired. Please log in again.';
  static const String logoutConfirmTitle = 'Log out?';
  static const String logoutConfirmBody =
      'You will need to log in again to upload or download files.';
  static String logoutConfirmActive(int count) => count == 1
      ? '1 transfer is still running and will be canceled.'
      : '$count transfers are still running and will be canceled.';
  static const String errorNetwork =
      'Can\'t reach the server. Check your internet connection and try again.';
  static const String errorUnauthorized =
      'Your session has expired. Please log in again.';
  static const String errorInvalidCredentials =
      'Incorrect username or password.';
  static const String errorFileGone = 'This file is no longer on the server.';
  static const String errorServer =
      'The server ran into a problem. Please try again in a moment.';
  static const String errorFileTooLarge =
      'This file is larger than the 512 MB limit.';
  static const String errorRejectedFile =
      'The server rejected this file. Please choose a different one.';
  static const String errorUnreadableFile =
      'We couldn\'t read that file. It may have been moved, deleted, or isn\'t supported.';
  static const String errorStorage =
      'Not enough storage space to save this file.';
  static const String errorResumeFailed =
      'Couldn\'t continue where it stopped. Starting again from the beginning.';
  static const String errorResumeNotSupported =
      'This server can\'t continue an interrupted upload, so it starts again '
      'from the beginning.';
  static const String errorAlreadyDownloading =
      'This file is already downloading.';
  static String errorCannotOpen(String path) =>
      'No app on this device can open this file. It is saved at $path.';
  static const String errorNotAllowed =
      'This action isn\'t available right now.';
  static const String errorUnknown = 'Something went wrong. Please try again.';
  static const String errorPicker =
      'We couldn\'t open the file picker. Please try again.';
  static const String tabUpload = 'Upload';
  static const String tabFiles = 'Files';
  static const String tabTransfers = 'Transfers';
  static String transfersBadgeTooltip(int count) => switch (count) {
    0 => 'Transfers',
    1 => 'Transfers, 1 active',
    _ => 'Transfers, $count active',
  };
  static String miniBannerActive(int count, int percent) =>
      '${count == 1 ? '1 transfer' : '$count transfers'} in progress · $percent%';
  static String miniBannerFailed(int count) =>
      count == 1 ? '1 transfer failed' : '$count transfers failed';
  // Covers both halves of what the app actually detects: no network at all,
  // and a network that cannot reach the server.
  static const String offlineBanner =
      'No connection to the server. Transfers are on hold and continue by '
      'themselves once it is back.';
  static const String notificationsOffBanner =
      'Notifications are off, so you won\'t see progress in the status bar.';
  static const String uploadTitle = 'Upload a file';
  static const String uploadChooseFile = 'Choose file';
  static const String uploadCaption = 'Images, videos or CSV · up to 512 MB';
  static const String uploadPreparing = 'Preparing file...';
  static const String uploadButton = 'Upload';
  static const String uploadStarting = 'Starting...';
  static const String uploadRemoveFile = 'Remove file';
  static const String uploadBackgroundHint =
      'You can leave this screen. The upload continues in the background.';
  static String pausedResumesFrom(String position) =>
      'Continues from $position when resumed.';
  static const String pausedStartsOver =
      'Starts again from the beginning when resumed.';
  static String offlineResumesFrom(String position) =>
      'No internet. Continues from $position as soon as the connection is '
      'back.';
  static const String offlineStartsOver =
      'No internet. Starts again from the beginning as soon as the connection '
      'is back.';
  static String pausedByNetworkSnack(String name) =>
      'Connection lost. $name is on hold and continues by itself.';
  static String resumedFromSnack(String name, String position) =>
      'Back online. $name continues from $position.';
  static const String uploadDone = 'Uploaded';
  static const String uploadViewInFiles = 'View in Files';
  static const String uploadAnother = 'Upload another';
  static const String uploadChooseAnother = 'Choose another file';
  static const String validationEmpty = 'This file is empty.';
  static const String validationTooLarge =
      'This file is larger than the 512 MB limit.';
  static const String validationUnsupported =
      'This file type isn\'t supported. Choose an image, video or CSV file.';
  static const String validationUnreadable =
      'We couldn\'t read that file. It may have been moved, deleted, or isn\'t supported.';
  static String timeLeftSeconds(int count) => '$count s left';
  static String timeLeftMinutes(int count) => '$count min left';
  static String timeLeftHours(int count) => '$count h left';
  static const String statusQueued = 'Queued';
  static const String statusUploading = 'Uploading';
  static const String statusDownloading = 'Downloading';
  static const String statusPaused = 'Paused';
  static const String statusPausedNoNetwork = 'Waiting for internet';
  static const String statusWaitingToRetry = 'Waiting for network';
  static const String statusWaitingDetail = 'Waiting for network, retrying...';
  static const String statusCompleted = 'Completed';
  static const String statusFailed = 'Failed';
  static const String statusCanceled = 'Canceled';
  static const String filesTitle = 'Your files';
  static const String filesEmpty = 'No files yet. Upload one first.';
  static const String filesEmptyAction = 'Go to Upload';
  static const String download = 'Download';
  static const String downloadStarted = 'Download started';
  static String autoResumedSnack(String name) => 'Back online. Retrying $name.';
  static const String syncedJustNow = 'Synced just now';
  static String syncedAt(String time) => 'Synced $time';
  static const String neverSynced = 'Not synced yet';
  static const String showingOfflineCopy = 'Offline copy';
  static const String syncing = 'Syncing...';
  static const String statTransferred = 'Transferred';
  static const String statSpeed = 'Speed';
  static const String statRemaining = 'Remaining';
  static const String valueUnknown = '--';
  static const String deleteConfirmTitle = 'Delete file?';
  static String deleteConfirmBody(String name) =>
      '$name will be removed from the server. This can\'t be undone.';
  static String fileDeleted(String name) => '$name was deleted.';
  static String fileSizeAndDate(String size, String date) => '$size · $date';
  static const String transfersTitle = 'Transfers';
  static String filterAll(int count) => 'All ($count)';
  static String filterActive(int count) => 'Active ($count)';
  static String filterCompleted(int count) => 'Completed ($count)';
  static String filterFailed(int count) => 'Failed ($count)';
  static const String filterAllLabel = 'All';
  static const String filterActiveLabel = 'Active';
  static const String filterCompletedLabel = 'Completed';
  static const String filterFailedLabel = 'Failed';
  static const String clearFinished = 'Clear finished';
  static const String transfersEmpty =
      'No transfers yet. Uploads and downloads will show up here.';
  static const String transfersEmptyFiltered = 'Nothing here right now.';
  static String savedTo(String path) => 'Saved to $path';
  static const String relativeJustNow = 'Just now';
  static String relativeMinutes(int count) => '$count min ago';
  static String relativeHours(int count) => '$count h ago';
  static String relativeDays(int count) =>
      count == 1 ? 'Yesterday' : '$count days ago';
  static String uploadCompletedSnack(String name) => '$name was uploaded.';
  static String downloadCompletedSnack(String name) => '$name was saved.';
  static const String notificationRationaleTitle = 'Show transfer progress?';
  static const String notificationRationaleBody =
      'Allow notifications to follow uploads and downloads from the status bar and get notified when they finish, even when the app is in the background.';
  static String notificationUploadingTitle(String name) => 'Uploading $name';
  static const String notificationUploadPausedTitle = 'Upload paused';
  static const String notificationUploadCompleteTitle = 'Upload complete';
  static String notificationUploadCompleteBody(String name) =>
      '$name was uploaded. Tap to view your files.';
  static const String notificationUploadFailedTitle = 'Upload failed';
  static String notificationUploadFailedBody(String name) =>
      '$name couldn\'t be uploaded. Tap for details.';
  static String notificationDownloadingTitle(String name) =>
      'Downloading $name';
  static const String notificationDownloadPausedTitle = 'Download paused';
  static const String notificationDownloadCompleteTitle = 'Download complete';
  static String notificationDownloadCompleteBody(String name) =>
      '$name was saved. Tap to open Transfers.';
  static const String notificationDownloadFailedTitle = 'Download failed';
  static String notificationDownloadFailedBody(String name) =>
      '$name couldn\'t be downloaded. Tap for details.';
  static String notificationRunningBody(
    String progress,
    String speed,
    String remaining,
  ) => '$progress · $speed · $remaining left';
}
