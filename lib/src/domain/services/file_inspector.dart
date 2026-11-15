/// Read-only file system checks used by upload validation.
abstract interface class FileInspector {
  Future<bool> exists(String path);

  Future<bool> isReadable(String path);

  Future<int> length(String path);
}
