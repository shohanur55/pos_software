import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/data/services/network/endpoints.dart';

void main() {
  group('Endpoints', () {
    test('builds the upload URL from the base URL', () {
      expect(Endpoints.uploadUrl, '${Endpoints.baseUrl}/upload');
    });

    test(
      'encodes spaces, unicode and reserved characters in download names',
      () {
        final url = Uri.parse(
          Endpoints.downloadUrl('sales & stock #1 রিপোর্ট.csv'),
        );
        expect(url.path, '/get');
        expect(url.queryParameters['file'], 'sales & stock #1 রিপোর্ট.csv');
        expect(Endpoints.downloadUrl('a&b.csv'), contains('file=a%26b.csv'));
        expect(Endpoints.downloadUrl('a#b.csv'), contains('file=a%23b.csv'));
      },
    );

    test('keeps absolute URLs untouched', () {
      expect(
        Endpoints.resolve('https://cdn.example.com/x.csv'),
        'https://cdn.example.com/x.csv',
      );
    });

    test('resolves server-relative paths against the base URL', () {
      expect(
        Endpoints.resolve('/get?file=x.csv'),
        '${Endpoints.baseUrl}/get?file=x.csv',
      );
      expect(
        Endpoints.resolve('uploads/x.csv'),
        '${Endpoints.baseUrl}/uploads/x.csv',
      );
    });

    test('encodes spaces in relative paths', () {
      expect(
        Endpoints.resolve('/uploads/my file.csv'),
        '${Endpoints.baseUrl}/uploads/my%20file.csv',
      );
    });
  });
}
