abstract final class Endpoints {
  /// The only place the server address is defined.
  static const String baseUrl = 'http://108.136.142.112:90';

  // Paths stay compile-time constants because Retrofit annotations need them.
  static const String token = '/token';
  static const String files = '/get';
  static const String upload = '/upload';
  static const String delete = '/delete';

  static const String fileQuery = 'file';

  static String get uploadUrl => '$baseUrl$upload';

  /// Builds the download URL with a properly encoded `file` query parameter.
  static String downloadUrl(String fileName) =>
      Uri.parse('$baseUrl$files')
          .replace(queryParameters: {fileQuery: fileName})
          .toString();

  /// Resolves an absolute URL or a server-relative path against [baseUrl].
  static String resolve(String urlOrPath) {
    final trimmed = urlOrPath.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme && parsed.host.isNotEmpty) {
      return parsed.toString();
    }
    final base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/');
    final relative = Uri.parse(
      Uri.encodeFull(trimmed.startsWith('/') ? trimmed.substring(1) : trimmed),
    );
    return base.resolveUri(relative).toString();
  }
}
