/// Opens a URL outside the app, in the device browser.
abstract class ExternalLinkService {
  /// Returns `false` when no browser on the device accepted the URL.
  Future<bool> open(String url);
}
