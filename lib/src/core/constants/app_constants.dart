abstract final class AppConstants {
  static const String appName = 'POS Software';

  /// Folder name used for downloads in shared storage and app documents.
  static const String downloadFolderName = 'POS Software';

  /// Private working folder for in-flight downloads.
  static const String transferFolderName = 'transfers';

  /// Private folder holding the picker's copy of a file being uploaded, for
  /// as long as the upload might still need it.
  static const String uploadSourceFolderName = 'upload_sources';

  static const double compactBreakpoint = 840;
  static const double maxContentWidth = 720;
}
