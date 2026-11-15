abstract final class ByteFormatter {
  static const List<String> _units = ['B', 'KB', 'MB', 'GB', 'TB'];

  /// Formats [bytes] using binary multiples with one decimal, e.g. `58.1 MB`.
  static String format(int bytes) {
    if (bytes <= 0) return '0 B';
    var value = bytes.toDouble();
    var unit = 0;
    while (value >= 1024 && unit < _units.length - 1) {
      value /= 1024;
      unit++;
    }
    final text = unit == 0
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
    return '$text ${_units[unit]}';
  }

  /// Formats a transfer speed, e.g. `2.3 MB/s`.
  static String formatSpeed(double bytesPerSecond) =>
      '${format(bytesPerSecond.round())}/s';
}
