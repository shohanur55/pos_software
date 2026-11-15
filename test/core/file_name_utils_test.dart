import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/core/utils/file_name_utils.dart';

void main() {
  group('FileNameUtils.sanitize', () {
    test('replaces characters illegal on mobile file systems', () {
      expect(
        FileNameUtils.sanitize('a/b\\c:d*e?f"g<h>i|j.csv'),
        'a_b_c_d_e_f_g_h_i_j.csv',
      );
    });

    test('collapses whitespace and strips leading dots', () {
      expect(FileNameUtils.sanitize('  ..my   report.csv '), 'my report.csv');
    });

    test('falls back when nothing usable remains', () {
      expect(FileNameUtils.sanitize('...'), 'file');
    });

    test('keeps unicode characters', () {
      expect(
        FileNameUtils.sanitize('বিক্রয় রিপোর্ট.csv'),
        'বিক্রয় রিপোর্ট.csv',
      );
    });
  });

  group('FileNameUtils.unique', () {
    test('returns the name when it is free', () {
      expect(
        FileNameUtils.unique('report.csv', const ['other.csv']),
        'report.csv',
      );
    });

    test('appends the first free index', () {
      expect(
        FileNameUtils.unique('report.csv', const ['report.csv']),
        'report (1).csv',
      );
      expect(
        FileNameUtils.unique('report.csv', const [
          'report.csv',
          'report (1).csv',
        ]),
        'report (2).csv',
      );
    });

    test('compares case-insensitively', () {
      expect(
        FileNameUtils.unique('Report.CSV', const ['report.csv']),
        'Report (1).CSV',
      );
    });

    test('handles names without an extension', () {
      expect(FileNameUtils.unique('notes', const ['notes']), 'notes (1)');
    });
  });

  test('extensionOf lower-cases and drops the dot', () {
    expect(FileNameUtils.extensionOf('Video.MP4'), 'mp4');
    expect(FileNameUtils.extensionOf('noext'), '');
  });

  test('shortLocation keeps only the last path segments', () {
    expect(
      FileNameUtils.shortLocation(
        '/storage/emulated/0/Download/POS Software/a.csv',
      ),
      'Download/POS Software/a.csv',
    );
    expect(FileNameUtils.shortLocation('/tmp/a.csv'), 'tmp/a.csv');
    expect(FileNameUtils.shortLocation('a.csv'), 'a.csv');
  });
}
