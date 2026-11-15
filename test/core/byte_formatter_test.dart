import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/core/utils/byte_formatter.dart';

void main() {
  group('ByteFormatter.format', () {
    test('handles zero and negative values', () {
      expect(ByteFormatter.format(0), '0 B');
      expect(ByteFormatter.format(-5), '0 B');
    });

    test('uses whole bytes below one kilobyte', () {
      expect(ByteFormatter.format(512), '512 B');
    });

    test('uses one decimal for larger units', () {
      expect(ByteFormatter.format(1536), '1.5 KB');
      expect(ByteFormatter.format(58 * 1024 * 1024 + 100 * 1024), '58.1 MB');
      expect(ByteFormatter.format(512 * 1024 * 1024), '512.0 MB');
      expect(ByteFormatter.format(3 * 1024 * 1024 * 1024), '3.0 GB');
    });

    test('formats speed per second', () {
      expect(ByteFormatter.formatSpeed(2.3 * 1024 * 1024), '2.3 MB/s');
    });
  });
}
