abstract final class TransferConstants {
  static const int maxUploadBytes = 512 * 1024 * 1024;

  static const Set<String> imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'gif',
  };
  static const Set<String> videoExtensions = {
    'mp4',
    'mov',
    'mkv',
    'avi',
    'webm',
  };
  static const Set<String> documentExtensions = {'csv'};

  static const Set<String> allowedUploadExtensions = {
    ...imageExtensions,
    ...videoExtensions,
    ...documentExtensions,
  };

  static const String uploadGroup = 'pos_uploads';
  static const String downloadGroup = 'pos_downloads';

  static const String uploadFileField = 'file';
  static const int retries = 3;

  /// Minimum gap between two progress events of the same transfer.
  static const Duration progressInterval = Duration(milliseconds: 250);
}
