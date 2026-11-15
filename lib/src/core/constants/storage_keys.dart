abstract final class StorageKeys {
  static const String session = 'auth.session';
  static const String transfers = 'transfers.records';
  static const String notificationPermissionAsked =
      'permissions.notifications.asked';

  /// Whether the configured server answers resumable-upload offset requests.
  static const String uploadResumeSupport = 'transfers.upload.resumeSupport';
}
