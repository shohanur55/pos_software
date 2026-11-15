import 'dart:io';

import '../../../domain/services/file_inspector.dart';

class FileInspectorImpl implements FileInspector {
  @override
  Future<bool> exists(String path) => File(path).exists();

  /// Opening and closing the file is the only reliable readability check on
  /// both platforms; it reads no bytes.
  @override
  Future<bool> isReadable(String path) async {
    try {
      final handle = await File(path).open();
      await handle.close();
      return true;
    } on FileSystemException {
      return false;
    }
  }

  @override
  Future<int> length(String path) => File(path).length();
}
