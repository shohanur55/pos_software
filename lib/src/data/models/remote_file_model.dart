import '../../domain/entities/remote_file_entity.dart';
import '../services/network/endpoints.dart';

class RemoteFileModel extends RemoteFileEntity {
  const RemoteFileModel({
    required super.name,
    required super.url,
    super.sizeBytes,
    super.uploadedAt,
  });

  static const List<String> nameKeys = [
    'name',
    'filename',
    'file',
    'file_name',
    'original_name',
  ];
  static const List<String> sizeKeys = [
    'size',
    'file_size',
    'bytes',
    'size_bytes',
  ];
  static const List<String> dateKeys = [
    'created_at',
    'uploaded_at',
    'modified',
    'updated_at',
    'date',
    'mtime',
  ];
  static const List<String> urlKeys = ['url', 'download_url', 'path'];

  /// Accepts a plain file name or an object using any of the known keys.
  /// Returns `null` when no name can be found.
  static RemoteFileModel? tryParse(Object? json) {
    if (json is String) return _fromName(json);
    if (json is! Map) return null;
    final map = json.map((key, value) => MapEntry(key.toString(), value));
    final name = _firstString(map, nameKeys);
    if (name == null) return null;
    final url = _firstString(map, urlKeys);
    return RemoteFileModel(
      name: name,
      url: url == null ? Endpoints.downloadUrl(name) : Endpoints.resolve(url),
      sizeBytes: _firstInt(map, sizeKeys),
      uploadedAt: _firstDate(map, dateKeys),
    );
  }

  static RemoteFileModel? _fromName(String raw) {
    final name = raw.trim();
    if (name.isEmpty) return null;
    return RemoteFileModel(name: name, url: Endpoints.downloadUrl(name));
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int && value >= 0) return value;
      if (value is num && value >= 0) return value.round();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null && parsed >= 0) return parsed;
      }
    }
    return null;
  }

  static DateTime? _firstDate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
      if (value is int && value > 0) {
        // Treat small numbers as Unix seconds, large ones as milliseconds.
        final millis = value < 100000000000 ? value * 1000 : value;
        return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
      }
    }
    return null;
  }
}
