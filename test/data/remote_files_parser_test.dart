import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/data/models/remote_files_parser.dart';
import 'package:pos_software/src/data/services/network/endpoints.dart';

void main() {
  group('RemoteFilesParser.parseList', () {
    test('accepts a top-level array of strings', () {
      final files = RemoteFilesParser.parseList(['a.csv', 'b c.png', '  ']);
      expect(files.map((file) => file.name), ['a.csv', 'b c.png']);
      expect(files.first.url, Endpoints.downloadUrl('a.csv'));
    });

    for (final key in RemoteFilesParser.listKeys) {
      test('accepts the array under "$key"', () {
        final files = RemoteFilesParser.parseList({
          key: [
            {'name': 'x.csv'},
          ],
        });
        expect(files.single.name, 'x.csv');
      });
    }

    test('finds the array one level deeper', () {
      final files = RemoteFilesParser.parseList({
        'data': {
          'files': ['deep.csv'],
        },
      });
      expect(files.single.name, 'deep.csv');
    });

    test('reads each supported name, size, date and url key', () {
      final files = RemoteFilesParser.parseList([
        {
          'filename': 'a.csv',
          'file_size': 10,
          'uploaded_at': '2026-11-13T10:00:00Z',
          'download_url': '/get?file=a.csv',
        },
        {'file': 'b.csv', 'bytes': '20', 'modified': 1763028000},
        {
          'file_name': 'c.csv',
          'size': 30.0,
          'created_at': '2026-11-12T08:00:00+00:00',
          'url': 'http://other/c.csv',
        },
        {'name': 'd.csv', 'path': 'files/d.csv'},
      ]);
      expect(files.map((file) => file.name), [
        'a.csv',
        'b.csv',
        'c.csv',
        'd.csv',
      ]);
      expect(files.map((file) => file.sizeBytes), [10, 20, 30, null]);
      expect(files[0].uploadedAt, DateTime.utc(2026, 11, 13, 10));
      expect(
        files[1].uploadedAt,
        DateTime.fromMillisecondsSinceEpoch(1763028000 * 1000, isUtc: true),
      );
      expect(files[0].url, '${Endpoints.baseUrl}/get?file=a.csv');
      expect(files[2].url, 'http://other/c.csv');
      expect(files[3].url, '${Endpoints.baseUrl}/files/d.csv');
    });

    test('decodes a JSON string body', () {
      expect(RemoteFilesParser.parseList('["a.csv"]').single.name, 'a.csv');
    });

    test('skips entries without a name instead of failing', () {
      final files = RemoteFilesParser.parseList([
        {'size': 1},
        42,
        null,
        {'name': 'ok.csv'},
      ]);
      expect(files.single.name, 'ok.csv');
    });

    test('ignores malformed sizes and dates', () {
      final file = RemoteFilesParser.parseList([
        {'name': 'a.csv', 'size': 'big', 'created_at': 'yesterday'},
      ]).single;
      expect(file.sizeBytes, isNull);
      expect(file.uploadedAt, isNull);
    });

    test('throws an invalidResponse failure for unknown shapes', () {
      expect(
        () => RemoteFilesParser.parseList({'message': 'ok'}),
        throwsA(
          isA<Failure>().having(
            (failure) => failure.kind,
            'kind',
            FailureKind.invalidResponse,
          ),
        ),
      );
      expect(() => RemoteFilesParser.parseList(null), throwsA(isA<Failure>()));
    });

    test(
      'throws FormatException for broken JSON so the repository can map it',
      () {
        expect(
          () => RemoteFilesParser.parseList('{not json'),
          throwsFormatException,
        );
      },
    );
  });

  group('RemoteFilesParser.parseUploaded', () {
    test('reads a flat object', () {
      expect(
        RemoteFilesParser.parseUploaded('{"success":true,"filename":"a_b.csv"}')
            ?.name,
        'a_b.csv',
      );
    });

    test('reads a nested file object', () {
      expect(
        RemoteFilesParser.parseUploaded({
          'file': {'name': 'n.csv'},
        })?.name,
        'n.csv',
      );
      expect(
        RemoteFilesParser.parseUploaded({
          'data': [
            {'name': 'first.csv'},
          ],
        })?.name,
        'first.csv',
      );
    });

    test('reads a plain string under "file"', () {
      expect(
        RemoteFilesParser.parseUploaded({
          'success': true,
          'file': 'renamed.csv',
        })?.name,
        'renamed.csv',
      );
    });

    test('returns null when there is no usable name', () {
      expect(
        RemoteFilesParser.parseUploaded(
          '{"success":true,"message":"Uploaded"}',
        ),
        isNull,
      );
      expect(RemoteFilesParser.parseUploaded(''), isNull);
      expect(RemoteFilesParser.parseUploaded('not json'), isNull);
      expect(RemoteFilesParser.parseUploaded(null), isNull);
    });
  });
}
