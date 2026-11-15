import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

/// Deep-links to the app's system settings. `background_downloader` can
/// request permissions but cannot open settings after a permanent denial.
class SystemSettingsService {
  Future<bool> openAppSettings() => permission_handler.openAppSettings();
}
