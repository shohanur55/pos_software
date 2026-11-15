import 'dart:convert';

import '../../core/base/failure.dart';
import 'remote_file_model.dart';

/// Parses the undocumented list and upload responses defensively.
abstract final class RemoteFilesParser {
  static const List<String> listKeys = [
    'files',
    'data',
    'items',
    'result',
    'results',
  ];

  /// Accepts a top-level array or an object holding the array under a known
  /// key. Throws a [Failure] with [FailureKind.invalidResponse] otherwise.
  static List<RemoteFileModel> parseList(Object? body) {
    final decoded = _decode(body);
    final list = _findList(decoded);
    if (list == null) {
      throw const Failure(
        FailureKind.invalidResponse,
        'Unexpected file list shape',
      );
    }
    return list
        .map(RemoteFileModel.tryParse)
        .whereType<RemoteFileModel>()
        .toList();
  }

  /// Extracts the stored file from an upload response, or `null` when the body
  /// carries no usable name.
  static RemoteFileModel? parseUploaded(Object? body) {
    final Object? decoded;
    try {
      decoded = _decode(body);
    } on FormatException {
      return null;
    }
    if (decoded is Map) {
      final map = decoded.map((key, value) => MapEntry(key.toString(), value));
      for (final key in const ['file', 'data', 'result', 'uploaded']) {
        final nested = map[key];
        if (nested is Map) {
          final parsed = RemoteFileModel.tryParse(nested);
          if (parsed != null) return parsed;
        }
        if (nested is List && nested.isNotEmpty) {
          final parsed = RemoteFileModel.tryParse(nested.first);
          if (parsed != null) return parsed;
        }
      }
      return RemoteFileModel.tryParse(map);
    }
    return null;
  }

  static Object? _decode(Object? body) {
    if (body is String) {
      final trimmed = body.trim();
      if (trimmed.isEmpty) return null;
      return jsonDecode(trimmed);
    }
    return body;
  }

  static List<Object?>? _findList(Object? decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      for (final key in listKeys) {
        final value = decoded[key];
        if (value is List) return value;
        if (value is Map) {
          final nested = _findList(value);
          if (nested != null) return nested;
        }
      }
    }
    return null;
  }
}
