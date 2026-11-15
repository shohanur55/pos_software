import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/data/models/remote_file_model.dart';
import 'package:pos_software/src/data/models/transfer_model.dart';
import 'package:pos_software/src/data/services/database/app_database.dart';
import 'package:pos_software/src/data/services/database/remote_file_dao.dart';
import 'package:pos_software/src/data/services/database/transfer_dao.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase database;
  late TransferDao transfers;
  late RemoteFileDao files;

  final created = DateTime.utc(2026, 11, 14, 9);

  TransferModel transfer({
    String id = 't1',
    TransferStatus status = TransferStatus.running,
    TransferType type = TransferType.upload,
    DateTime? createdAt,
  }) => TransferModel(
    id: id,
    taskId: 'task-$id',
    type: type,
    fileName: 'catalog.csv',
    status: status,
    createdAt: createdAt ?? created,
    updatedAt: createdAt ?? created,
    totalBytes: 2048,
    progress: 0.5,
    transferredBytes: 1024,
    localPath: '/tmp/catalog.csv',
  );

  setUp(() async {
    database = AppDatabase(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    transfers = TransferDao(database);
    files = RemoteFileDao(database);
  });

  tearDown(() => database.close());

  group('TransferDao', () {
    test('stores and reads a transfer unchanged', () async {
      final original = transfer().copyWith(
        status: TransferStatus.failed,
        errorKind: TransferErrorKind.network,
        errorMessage: 'reset by peer',
        remoteFileName: 'catalog_1.csv',
        savedPath: '/storage/catalog.csv',
        canPauseNatively: true,
        pendingFinalize: true,
      );
      await transfers.upsert(original);

      expect(await transfers.all(), [original]);
    });

    test('upsert replaces the row with the same id', () async {
      await transfers.upsert(transfer());
      await transfers.upsert(
        transfer().copyWith(status: TransferStatus.completed, progress: 1),
      );

      final stored = await transfers.all();
      expect(stored, hasLength(1));
      expect(stored.single.status, TransferStatus.completed);
    });

    test('returns the newest transfer first', () async {
      await transfers.upsert(
        transfer(
          id: 'old',
          createdAt: created.subtract(const Duration(hours: 2)),
        ),
      );
      await transfers.upsert(transfer(id: 'new'));

      expect((await transfers.all()).map((item) => item.id), ['new', 'old']);
    });

    test('deletes by id and in bulk', () async {
      await transfers.upsert(transfer(id: 'a'));
      await transfers.upsert(transfer(id: 'b'));
      await transfers.upsert(transfer(id: 'c'));

      await transfers.deleteByIds(['a', 'c']);
      expect((await transfers.all()).map((item) => item.id), ['b']);

      await transfers.deleteByIds(const []);
      expect(await transfers.all(), hasLength(1));

      await transfers.deleteAll();
      expect(await transfers.all(), isEmpty);
    });

    test('history survives reopening the database', () async {
      const path = '${inMemoryDatabasePath}_reopen';
      final first = AppDatabase(factory: databaseFactoryFfi, path: path);
      await TransferDao(first).upsert(transfer(id: 'kept'));
      await first.close();

      final second = AppDatabase(factory: databaseFactoryFfi, path: path);
      addTearDown(second.close);
      expect((await TransferDao(second).all()).single.id, 'kept');
    });
  });

  group('RemoteFileDao', () {
    final catalog = RemoteFileModel(
      name: 'catalog.csv',
      url: 'http://host/get?file=catalog.csv',
      sizeBytes: 2048,
      uploadedAt: created,
    );
    const photo = RemoteFileModel(
      name: 'photo.png',
      url: 'http://host/get?file=photo.png',
    );

    test('keeps the server order and reports when it was cached', () async {
      await files.replaceAll([catalog, photo], created);

      expect((await files.all()).map((file) => file.name), [
        'catalog.csv',
        'photo.png',
      ]);
      expect(await files.cachedAt(), created);
    });

    test(
      'round-trips size and date, including when they are unknown',
      () async {
        await files.replaceAll([catalog, photo], created);

        final stored = await files.all();
        expect(stored.first.sizeBytes, 2048);
        expect(stored.first.uploadedAt, created);
        expect(stored.last.sizeBytes, isNull);
        expect(stored.last.uploadedAt, isNull);
      },
    );

    test('replaceAll swaps the whole list', () async {
      await files.replaceAll([catalog, photo], created);
      await files.replaceAll([photo], created.add(const Duration(minutes: 5)));

      expect((await files.all()).map((file) => file.name), ['photo.png']);
      expect(await files.cachedAt(), created.add(const Duration(minutes: 5)));
    });

    test('deletes one file and clears the cache', () async {
      await files.replaceAll([catalog, photo], created);

      await files.delete('catalog.csv');
      expect((await files.all()).map((file) => file.name), ['photo.png']);

      await files.clear();
      expect(await files.all(), isEmpty);
      expect(await files.cachedAt(), isNull);
    });
  });
}
