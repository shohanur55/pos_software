import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/data/models/transfer_events.dart';
import 'package:pos_software/src/data/models/transfer_model.dart';
import 'package:pos_software/src/data/repositories/transfer_repository_impl.dart';
import 'package:pos_software/src/data/services/cache/cache_service.dart';
import 'package:pos_software/src/data/services/cache/session_storage.dart';
import 'package:pos_software/src/data/services/database/transfer_dao.dart';
import 'package:pos_software/src/data/services/network/rest_client.dart';
import 'package:pos_software/src/data/services/system/system_settings_service.dart';
import 'package:pos_software/src/data/services/transfer/background_transfer_service.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockTransferDao extends Mock implements TransferDao {}

class MockBackgroundTransferService extends Mock
    implements BackgroundTransferService {}

class MockSessionStorage extends Mock implements SessionStorage {}

class MockRestClient extends Mock implements RestClient {}

class MockSystemSettingsService extends Mock implements SystemSettingsService {}

class MockCacheService extends Mock implements CacheService {}

void main() {
  sqfliteFfiInit();

  late MockTransferDao dao;
  late MockBackgroundTransferService service;
  late TransferRepositoryImpl repository;

  final now = DateTime.utc(2026, 11, 14, 9);

  TransferRepositoryImpl build() => TransferRepositoryImpl(
    service,
    dao,
    MockSessionStorage(),
    MockRestClient(),
    MockSystemSettingsService(),
    MockCacheService(),
    clock: () => now,
  );

  setUp(() {
    dao = MockTransferDao();
    service = MockBackgroundTransferService();
    when(() => service.events)
        .thenAnswer((_) => const Stream<TransferTaskEvent>.empty());
    repository = build();
  });

  TransferModel row(String id) => TransferModel(
    id: id,
    taskId: 'task-$id',
    type: TransferType.upload,
    fileName: '$id.csv',
    status: TransferStatus.completed,
    createdAt: now,
    updatedAt: now,
    progress: 1,
  );

  test('reads the history from the database once', () async {
    when(() => dao.all()).thenAnswer((_) async => [row('a'), row('b')]);

    final first = await repository.getTransfers();
    final second = await repository.getTransfers();

    expect(first.dataOrNull, hasLength(2));
    expect(second.dataOrNull, hasLength(2));
    verify(() => dao.all()).called(1);
  });

  test('a failed read is reported and retried on the next call', () async {
    var attempts = 0;
    when(() => dao.all()).thenAnswer((_) async {
      attempts++;
      if (attempts == 1) {
        throw const FileSystemException('database is locked', 'pos.db');
      }
      return [row('a')];
    });

    final failed = await repository.getTransfers();
    expect(failed, isA<Error<dynamic, Failure>>());
    expect((failed as Error).error.kind, FailureKind.storage);

    // The app must recover rather than stay empty for the rest of the session.
    final recovered = await repository.getTransfers();
    expect(recovered.dataOrNull, hasLength(1));
    expect(attempts, 2);
  });

  test(
    'removing a finished transfer deletes its row and its native record',
    () async {
      when(() => dao.all()).thenAnswer((_) async => [row('a')]);
      when(() => dao.deleteByIds(any())).thenAnswer((_) async {});
      when(() => service.deleteRecord(any())).thenAnswer((_) async {});
      await repository.getTransfers();

      final removed = await repository.remove('a');

      expect(removed, isA<Success<dynamic, Failure>>());
      verify(() => dao.deleteByIds(['a'])).called(1);
    },
  );

  test('refuses to remove a transfer that is still running', () async {
    final running = row('a').copyWith(status: TransferStatus.running);
    when(() => dao.all()).thenAnswer((_) async => [running]);
    await repository.getTransfers();

    final result = await repository.remove('a');

    expect((result as Error).error.kind, FailureKind.notAllowed);
    verifyNever(() => dao.deleteByIds(any()));
  });

  test('an unknown id is reported as not found', () async {
    when(() => dao.all()).thenAnswer((_) async => []);

    final result = await repository.pause('ghost');

    expect((result as Error).error.kind, FailureKind.notFound);
  });
}
