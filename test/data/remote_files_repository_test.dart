import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/data/repositories/remote_files_repository_impl.dart';
import 'package:pos_software/src/data/services/database/app_database.dart';
import 'package:pos_software/src/data/services/database/remote_file_dao.dart';
import 'package:pos_software/src/data/services/network/rest_client.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockRestClient extends Mock implements RestClient {}

void main() {
  sqfliteFfiInit();

  late MockRestClient client;
  late AppDatabase database;
  late RemoteFilesRepositoryImpl repository;

  final now = DateTime.utc(2026, 11, 14, 9);

  setUp(() {
    client = MockRestClient();
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = RemoteFilesRepositoryImpl(
      client,
      RemoteFileDao(database),
      clock: () => now,
    );
  });

  tearDown(() => database.close());

  DioException offline() => DioException(
    requestOptions: RequestOptions(path: '/get'),
    type: DioExceptionType.connectionError,
  );

  test('an empty cache reports that it never synced', () async {
    final result = await repository.getCachedFiles();

    expect(result, isA<Success<dynamic, Failure>>());
    final snapshot = result.dataOrNull!;
    expect(snapshot.files, isEmpty);
    expect(snapshot.hasNeverSynced, isTrue);
    expect(snapshot.fromCache, isTrue);
  });

  test(
    'a refresh stores the list so it is available offline afterwards',
    () async {
      when(() => client.getFiles()).thenAnswer(
        (_) async => [
          {
            'name': 'catalog.csv',
            'size': 2048,
            'created_at': '2026-11-14T08:00:00Z',
          },
          {'name': 'photo.png'},
        ],
      );

      final refreshed = (await repository.refreshFiles()).dataOrNull!;
      expect(refreshed.fromCache, isFalse);
      expect(refreshed.syncedAt, now);
      expect(refreshed.files.map((file) => file.name), [
        'catalog.csv',
        'photo.png',
      ]);

      // The server is gone; the cached list must still be there.
      when(() => client.getFiles()).thenThrow(offline());
      expect((await repository.refreshFiles()).dataOrNull, isNull);

      final cached = (await repository.getCachedFiles()).dataOrNull!;
      expect(cached.fromCache, isTrue);
      expect(cached.syncedAt, now);
      expect(cached.files.map((file) => file.name), [
        'catalog.csv',
        'photo.png',
      ]);
    },
  );

  test('sorts newest first and keeps undated files at the end', () async {
    when(() => client.getFiles()).thenAnswer(
      (_) async => [
        {'name': 'undated.csv'},
        {'name': 'old.csv', 'created_at': '2026-01-01T00:00:00Z'},
        {'name': 'new.csv', 'created_at': '2026-06-01T00:00:00Z'},
      ],
    );

    final files = (await repository.refreshFiles()).dataOrNull!.files;
    expect(files.map((file) => file.name), [
      'new.csv',
      'old.csv',
      'undated.csv',
    ]);
  });

  test('a network failure is reported as such, not as a crash', () async {
    when(() => client.getFiles()).thenThrow(offline());

    final result = await repository.refreshFiles();
    expect(result, isA<Error<dynamic, Failure>>());
    expect((result as Error).error.kind, FailureKind.network);
  });

  test('a malformed body is reported as an invalid response', () async {
    when(() => client.getFiles()).thenAnswer((_) async => {'message': 'hello'});

    final result = await repository.refreshFiles();
    expect((result as Error).error.kind, FailureKind.invalidResponse);
  });

  test('deleting drops the file from the cache too', () async {
    when(() => client.getFiles()).thenAnswer((_) async => ['a.csv', 'b.csv']);
    when(() => client.deleteFile('a.csv')).thenAnswer((_) async {});
    await repository.refreshFiles();

    await repository.deleteFile('a.csv');

    expect(
      (await repository.getCachedFiles()).dataOrNull!.files.map(
        (file) => file.name,
      ),
      ['b.csv'],
    );
  });

  test('a failed delete leaves the cache untouched', () async {
    when(() => client.getFiles()).thenAnswer((_) async => ['a.csv']);
    when(() => client.deleteFile('a.csv')).thenThrow(offline());
    await repository.refreshFiles();

    expect(
      await repository.deleteFile('a.csv'),
      isA<Error<dynamic, Failure>>(),
    );
    expect((await repository.getCachedFiles()).dataOrNull!.files, hasLength(1));
  });

  test('clearCache empties the offline copy on logout', () async {
    when(() => client.getFiles()).thenAnswer((_) async => ['a.csv']);
    await repository.refreshFiles();

    await repository.clearCache();

    final cached = (await repository.getCachedFiles()).dataOrNull!;
    expect(cached.files, isEmpty);
    expect(cached.hasNeverSynced, isTrue);
  });
}
