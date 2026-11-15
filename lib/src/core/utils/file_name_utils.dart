import 'package:path/path.dart' as p;

abstract final class FileNameUtils {
  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F]');
  static final RegExp _whitespace = RegExp(r'\s+');

  /// Replaces characters that are illegal on Android or iOS file systems.
  static String sanitize(String name, {String fallback = 'file'}) {
    final cleaned = name
        .replaceAll(_illegal, '_')
        .replaceAll(_whitespace, ' ')
        .trim();
    final withoutDots = cleaned.replaceAll(RegExp(r'^\.+'), '');
    return withoutDots.isEmpty ? fallback : withoutDots;
  }

  /// Last [segments] parts of [path], e.g. `Download/POS Software/a.csv`.
  /// Full device paths are long and mean little to users.
  static String shortLocation(String path, {int segments = 3}) {
    final parts = p.split(path).where((part) => part != p.separator).toList();
    if (parts.length <= segments) return parts.join('/');
    return parts.sublist(parts.length - segments).join('/');
  }

  /// Lower-case extension without the dot, or an empty string.
  static String extensionOf(String name) {
    final ext = p.extension(name);
    return ext.isEmpty ? '' : ext.substring(1).toLowerCase();
  }

  /// Returns [name] or the first `name (n).ext` that is not in [taken].
  ///
  /// Comparison is case-insensitive because both target file systems
  /// commonly are.
  static String unique(String name, Iterable<String> taken) {
    final used = {for (final value in taken) value.toLowerCase()};
    if (!used.contains(name.toLowerCase())) return name;
    final stem = p.basenameWithoutExtension(name);
    final ext = p.extension(name);
    var index = 1;
    while (used.contains('$stem ($index)$ext'.toLowerCase())) {
      index++;
    }
    return '$stem ($index)$ext';
  }
}
