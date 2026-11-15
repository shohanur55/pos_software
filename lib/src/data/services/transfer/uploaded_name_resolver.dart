import 'package:path/path.dart' as p;

import '../../models/remote_file_model.dart';

/// Finds the name the server stored an upload under.
///
/// The server may sanitize or suffix names, so the local name is only the
/// last resort.
abstract final class UploadedNameResolver {
  static String resolve({
    required String localName,
    required List<RemoteFileModel> files,
    DateTime? uploadedAfter,
  }) {
    if (files.isEmpty) return localName;
    final exact = files.where((file) => file.name == localName);
    if (exact.isNotEmpty) return exact.first.name;

    final normalized = _normalize(localName);
    final stem = _normalize(p.basenameWithoutExtension(localName));
    final ext = p.extension(localName).toLowerCase();
    final similar = files.where((file) {
      final name = _normalize(file.name);
      return name == normalized ||
          (name.startsWith(stem) && name.endsWith(ext));
    }).toList();
    if (similar.length == 1) return similar.first.name;

    final candidates = similar.isEmpty ? files : similar;
    final dated = candidates.where((file) {
      final uploadedAt = file.uploadedAt;
      return uploadedAt != null &&
          (uploadedAfter == null || !uploadedAt.isBefore(uploadedAfter));
    }).toList()..sort((a, b) => b.uploadedAt!.compareTo(a.uploadedAt!));
    if (dated.isNotEmpty) return dated.first.name;
    return similar.isNotEmpty ? similar.first.name : localName;
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '_');
}
