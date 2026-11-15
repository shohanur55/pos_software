import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/data/models/remote_file_model.dart';
import 'package:pos_software/src/data/services/transfer/progress_throttle.dart';
import 'package:pos_software/src/data/services/transfer/uploaded_name_resolver.dart';

void main() {
  group('ProgressThrottle', () {
    test('lets at most one event per interval through for each key', () {
      var now = DateTime(2026);
      final throttle = ProgressThrottle(
        const Duration(milliseconds: 250),
        clock: () => now,
      );
      expect(throttle.shouldEmit('a', 0.1), isTrue);
      now = now.add(const Duration(milliseconds: 100));
      expect(throttle.shouldEmit('a', 0.2), isFalse);
      expect(throttle.shouldEmit('b', 0.2), isTrue);
      now = now.add(const Duration(milliseconds: 150));
      expect(throttle.shouldEmit('a', 0.3), isTrue);
    });

    test('always lets the final 100% through', () {
      final now = DateTime(2026);
      final throttle = ProgressThrottle(
        const Duration(seconds: 1),
        clock: () => now,
      );
      expect(throttle.shouldEmit('a', 0.5), isTrue);
      expect(throttle.shouldEmit('a', 1), isTrue);
    });
  });

  group('UploadedNameResolver', () {
    RemoteFileModel file(String name, [DateTime? at]) =>
        RemoteFileModel(name: name, url: 'u', uploadedAt: at);

    test('prefers an exact match', () {
      expect(
        UploadedNameResolver.resolve(
          localName: 'a.csv',
          files: [file('b.csv'), file('a.csv')],
        ),
        'a.csv',
      );
    });

    test('matches a sanitized variant', () {
      expect(
        UploadedNameResolver.resolve(
          localName: 'My File.csv',
          files: [file('other.csv'), file('my_file.csv')],
        ),
        'my_file.csv',
      );
    });

    test('matches a suffixed variant', () {
      expect(
        UploadedNameResolver.resolve(
          localName: 'report.csv',
          files: [file('x.png'), file('report_1700000000.csv')],
        ),
        'report_1700000000.csv',
      );
    });

    test('picks the newest of several similar names', () {
      final files = [
        file('report_1.csv', DateTime(2026, 1, 1)),
        file('report_2.csv', DateTime(2026, 2, 1)),
      ];
      expect(
        UploadedNameResolver.resolve(localName: 'report.csv', files: files),
        'report_2.csv',
      );
    });

    test('falls back to the newest upload, then to the local name', () {
      final files = [
        file('x.png', DateTime(2026, 1, 1)),
        file('y.png', DateTime(2026, 3, 1)),
      ];
      expect(
        UploadedNameResolver.resolve(
          localName: 'z.csv',
          files: files,
          uploadedAfter: DateTime(2026, 2, 1),
        ),
        'y.png',
      );
      expect(
        UploadedNameResolver.resolve(
          localName: 'z.csv',
          files: [file('x.png')],
        ),
        'z.csv',
      );
      expect(
        UploadedNameResolver.resolve(localName: 'z.csv', files: const []),
        'z.csv',
      );
    });
  });
}
