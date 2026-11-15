import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/core/utils/duration_formatter.dart';

void main() {
  group('DurationFormatter.remaining', () {
    test('never reports less than one second', () {
      expect(
        DurationFormatter.remaining(Duration.zero),
        const RemainingTime(1, RemainingUnit.seconds),
      );
    });

    test('uses seconds below a minute', () {
      expect(
        DurationFormatter.remaining(const Duration(seconds: 20)),
        const RemainingTime(20, RemainingUnit.seconds),
      );
    });

    test('rounds minutes up', () {
      expect(
        DurationFormatter.remaining(const Duration(seconds: 61)),
        const RemainingTime(2, RemainingUnit.minutes),
      );
      expect(
        DurationFormatter.remaining(const Duration(minutes: 3)),
        const RemainingTime(3, RemainingUnit.minutes),
      );
    });

    test('uses hours from sixty minutes', () {
      expect(
        DurationFormatter.remaining(const Duration(minutes: 90)),
        const RemainingTime(2, RemainingUnit.hours),
      );
    });
  });
}
