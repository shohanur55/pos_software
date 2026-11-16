import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/data/models/auth_session_model.dart';
import 'package:pos_software/src/data/models/transfer_events.dart';
import 'package:pos_software/src/data/models/transfer_model.dart';
import 'package:pos_software/src/data/models/transfer_task_meta.dart';
import 'package:pos_software/src/data/repositories/transfer_repository_impl.dart';
import 'package:pos_software/src/data/services/cache/cache_service.dart';
import 'package:pos_software/src/data/services/cache/session_storage.dart';
import 'package:pos_software/src/data/services/database/transfer_dao.dart';
import 'package:pos_software/src/data/services/network/rest_client.dart';
import 'package:pos_software/src/data/services/system/system_settings_service.dart';
import 'package:pos_software/src/data/services/transfer/background_transfer_service.dart';
import 'package:pos_software/src/data/services/transfer/upload_resume_probe.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_pause_reason.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/domain/entities/upload_request_entity.dart';
import 'package:pos_software/src/domain/services/connectivity_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockTransferDao extends Mock implements TransferDao {}

class MockBackgroundTransferService extends Mock
    implements BackgroundTransferService {}

class MockSessionStorage extends Mock implements SessionStorage {}

class MockRestClient extends Mock implements RestClient {}

class MockSystemSettingsService extends Mock implements SystemSettingsService {}

class MockCacheService extends Mock implements CacheService {}

class MockConnectivityService extends Mock implements ConnectivityService {}

class MockUploadResumeProbe extends Mock implements UploadResumeProbe {}

void main() {
  sqfliteFfiInit();

  setUpAll(() {
    registerFallbackValue(
      TransferModel(
        id: 'fallback',
        taskId: 'fallback',
        type: TransferType.upload,
        fileName: 'fallback.csv',
        status: TransferStatus.queued,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    registerFallbackValue(
      TransferTaskMeta(
        transferId: 'fallback',
        type: TransferType.upload,
        displayName: 'fallback.csv',
        createdAt: DateTime.utc(2026),
      ),
    );
  });

  late MockTransferDao dao;
  late MockBackgroundTransferService service;
  late MockConnectivityService connectivity;
  late MockUploadResumeProbe resumeProbe;
  late MockSessionStorage sessionStorage;
  late StreamController<bool> online;
  late StreamController<TransferTaskEvent> taskEvents;
  late TransferRepositoryImpl repository;

  final now = DateTime.utc(2026, 11, 14, 9);

  TransferRepositoryImpl build() => TransferRepositoryImpl(
    service,
    dao,
    sessionStorage,
    MockRestClient(),
    MockSystemSettingsService(),
    MockCacheService(),
    connectivity,
    resumeProbe,
    clock: () => now,
  );

  setUp(() {
    dao = MockTransferDao();
    service = MockBackgroundTransferService();
    connectivity = MockConnectivityService();
    resumeProbe = MockUploadResumeProbe();
    sessionStorage = MockSessionStorage();
    online = StreamController<bool>.broadcast();
    taskEvents = StreamController<TransferTaskEvent>.broadcast();
    when(() => service.events).thenAnswer((_) => taskEvents.stream);
    when(connectivity.watchOnline).thenAnswer((_) => online.stream);
    when(sessionStorage.read).thenReturn(
      AuthSessionModel(
        token: 'fresh-token',
        tokenType: 'Bearer',
        expiresAt: now.add(const Duration(hours: 24)),
        userId: 1,
        username: 'cashier',
      ),
    );
    when(() => dao.upsert(any())).thenAnswer((_) async {});
    when(() => service.cancel(any())).thenAnswer((_) async {});
    when(() => service.deleteRecord(any())).thenAnswer((_) async {});
    when(() => service.deletePickedCopy(any())).thenAnswer((_) async {});
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

  /// A real file on disk, because a restart refuses to run when the upload
  /// source is gone.
  late Directory sandbox;
  late File source;

  setUp(() {
    sandbox = Directory.systemTemp.createTempSync('pos_transfers_test');
    source = File('${sandbox.path}/big_video.mp4')
      ..writeAsBytesSync(List<int>.filled(1024, 0));
  });

  /// Every row the repository wrote, in order.
  List<TransferModel> captureCommitted() =>
      verify(() => dao.upsert(captureAny())).captured.cast<TransferModel>();

  tearDown(() async {
    await taskEvents.close();
    await online.close();
    await repository.dispose();
    sandbox.deleteSync(recursive: true);
  });

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

  group('parking and resuming around the network', () {
    TransferModel download(
      String id, {
      TransferStatus status = TransferStatus.running,
      bool canPauseNatively = true,
      int transferredBytes = 80 * 1024 * 1024,
      TransferPauseReason? pauseReason,
    }) => TransferModel(
      id: id,
      taskId: 'task-$id',
      type: TransferType.download,
      fileName: '$id.mp4',
      remoteFileName: '$id.mp4',
      url: 'http://host/get?file=$id.mp4',
      status: status,
      createdAt: now,
      updatedAt: now,
      progress: 0.5,
      totalBytes: 160 * 1024 * 1024,
      transferredBytes: transferredBytes,
      canPauseNatively: canPauseNatively,
      pauseReason: pauseReason,
    );

    TransferModel upload(
      String id, {
      TransferStatus status = TransferStatus.running,
      int transferredBytes = 80 * 1024 * 1024,
      TransferPauseReason? pauseReason,
    }) => TransferModel(
      id: id,
      taskId: 'task-$id',
      type: TransferType.upload,
      fileName: '$id.mp4',
      localPath: source.path,
      status: status,
      createdAt: now,
      updatedAt: now,
      progress: 0.5,
      totalBytes: 160 * 1024 * 1024,
      transferredBytes: transferredBytes,
      pauseReason: pauseReason,
    );

    /// Lets the connectivity listener and the serialized write queue drain.
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    test(
      'losing the route parks a running download in place and says why',
      () async {
        when(() => dao.all()).thenAnswer((_) async => [download('a')]);
        when(() => service.pauseDownload('task-a'))
            .thenAnswer((_) async => true);
        await repository.getTransfers();

        online.add(false);
        await settle();

        final parked = captureCommitted().last;
        expect(parked.status, TransferStatus.paused);
        expect(parked.pauseReason, TransferPauseReason.noNetwork);
        expect(parked.transferredBytes, 80 * 1024 * 1024);
        // Paused in place, so the partial file and its offset stay on disk.
        verifyNever(() => service.cancel('task-a'));
      },
    );

    test('the route coming back resumes with a freshly read token', () async {
      when(() => dao.all()).thenAnswer(
        (_) async => [
          download(
            'a',
            status: TransferStatus.paused,
            pauseReason: TransferPauseReason.noNetwork,
          ),
        ],
      );
      when(
        () => service.resumeDownload(
          any(),
          authorization: any(named: 'authorization'),
        ),
      ).thenAnswer((_) async => true);
      await repository.getTransfers();

      online.add(true);
      await settle();

      verify(
        () => service.resumeDownload(
          'task-a',
          authorization: 'Bearer fresh-token',
        ),
      ).called(1);
      expect(captureCommitted().last.status, TransferStatus.queued);
    });

    test(
      'a transfer the operator paused is left alone when the route returns',
      () async {
        when(() => dao.all()).thenAnswer(
          (_) async => [
            download(
              'a',
              status: TransferStatus.paused,
              pauseReason: TransferPauseReason.user,
            ),
          ],
        );
        await repository.getTransfers();

        online.add(true);
        await settle();

        verifyNever(
          () => service.resumeDownload(
            any(),
            authorization: any(named: 'authorization'),
          ),
        );
      },
    );

    test(
      'a download that cannot pause in place is parked by cancelling it',
      () async {
        when(() => dao.all())
            .thenAnswer((_) async => [download('a', canPauseNatively: false)]);
        when(() => service.pauseDownload('task-a'))
            .thenAnswer((_) async => false);
        await repository.getTransfers();

        final paused = await repository.pause('a');

        expect(paused, isA<Success<dynamic, Failure>>());
        expect(captureCommitted().last.pauseReason, TransferPauseReason.user);
        verify(() => service.cancel('task-a')).called(1);
      },
    );

    test(
      'a download reported paused is known to have kept its place',
      () async {
        when(() => dao.all())
            .thenAnswer((_) async => [download('a', canPauseNatively: false)]);
        await repository.getTransfers();

        // The native side only reports paused once the partial file and offset
        // are stored, so the row can stop hedging about what resume will do.
        taskEvents.add(
          const TransferStatusEvent(
            'task-a',
            null,
            status: TransferStatus.paused,
          ),
        );
        await settle();

        final paused = captureCommitted().last;
        expect(paused.status, TransferStatus.paused);
        expect(paused.canPauseNatively, isTrue);
        expect(paused.resumesWhereItStopped, isTrue);
      },
    );

    test(
      'a pause the server refuses stays paused rather than failing',
      () async {
        when(() => dao.all()).thenAnswer(
          (_) async => [
            download(
              'a',
              status: TransferStatus.paused,
              canPauseNatively: true,
              pauseReason: TransferPauseReason.user,
            ),
          ],
        );
        await repository.getTransfers();

        taskEvents.add(
          const TransferStatusEvent(
            'task-a',
            null,
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.resumeFailed,
          ),
        );
        await settle();

        final row = captureCommitted().last;
        // The operator asked for a pause and got one; what changed is only
        // that it will have to start over.
        expect(row.status, TransferStatus.paused);
        expect(row.errorKind, isNull);
        expect(row.resumesWhereItStopped, isFalse);
      },
    );

    test(
      'resuming an upload the server cannot continue starts it over',
      () async {
        when(
          () => dao.all(),
        ).thenAnswer((_) async => [upload('a', status: TransferStatus.paused)]);
        when(
          () => resumeProbe.confirmedBytes(
            uploadId: any(named: 'uploadId'),
            totalBytes: any(named: 'totalBytes'),
            transferredBytes: any(named: 'transferredBytes'),
            authorization: any(named: 'authorization'),
          ),
        ).thenAnswer((_) async => null);
        when(
          () => service.enqueueUpload(
            taskId: any(named: 'taskId'),
            filePath: any(named: 'filePath'),
            authorization: any(named: 'authorization'),
            meta: any(named: 'meta'),
            resumeFromByte: any(named: 'resumeFromByte'),
          ),
        ).thenAnswer((_) async {});
        await repository.getTransfers();

        final resumed = await repository.resume('a');
        final transfer = resumed.dataOrNull!;

        expect(transfer.progress, 0);
        expect(transfer.transferredBytes, 0);
        expect(transfer.errorKind, TransferErrorKind.resumeNotSupported);
        verify(
          () => service.enqueueUpload(
            taskId: any(named: 'taskId'),
            filePath: source.path,
            authorization: 'Bearer fresh-token',
            meta: any(named: 'meta'),
            resumeFromByte: 0,
          ),
        ).called(1);
      },
    );

    test(
      'an endpoint that reports an offset resumes the upload from it',
      () async {
        const offset = 80 * 1024 * 1024;
        when(
          () => dao.all(),
        ).thenAnswer((_) async => [upload('a', status: TransferStatus.paused)]);
        when(
          () => resumeProbe.confirmedBytes(
            uploadId: any(named: 'uploadId'),
            totalBytes: any(named: 'totalBytes'),
            transferredBytes: any(named: 'transferredBytes'),
            authorization: any(named: 'authorization'),
          ),
        ).thenAnswer((_) async => offset);
        when(
          () => service.enqueueUpload(
            taskId: any(named: 'taskId'),
            filePath: any(named: 'filePath'),
            authorization: any(named: 'authorization'),
            meta: any(named: 'meta'),
            resumeFromByte: any(named: 'resumeFromByte'),
          ),
        ).thenAnswer((_) async {});
        await repository.getTransfers();

        final resumed = await repository.resume('a');
        final transfer = resumed.dataOrNull!;

        // The progress already on screen survives the resume.
        expect(transfer.transferredBytes, offset);
        expect(transfer.resumeFromByte, offset);
        expect(transfer.progress, closeTo(0.5, 0.001));
        expect(transfer.errorKind, isNull);
        verify(
          () => service.enqueueUpload(
            taskId: any(named: 'taskId'),
            filePath: source.path,
            authorization: 'Bearer fresh-token',
            meta: any(named: 'meta'),
            resumeFromByte: offset,
          ),
        ).called(1);
      },
    );

    test(
      'a flapping connection cannot restart the same upload forever',
      () async {
        when(() => dao.all()).thenAnswer(
          (_) async => [
            upload(
              'a',
              status: TransferStatus.paused,
              pauseReason: TransferPauseReason.noNetwork,
            ),
          ],
        );
        when(
          () => resumeProbe.confirmedBytes(
            uploadId: any(named: 'uploadId'),
            totalBytes: any(named: 'totalBytes'),
            transferredBytes: any(named: 'transferredBytes'),
            authorization: any(named: 'authorization'),
          ),
        ).thenAnswer((_) async => null);
        final enqueued = <String>[];
        when(
          () => service.enqueueUpload(
            taskId: any(named: 'taskId'),
            filePath: any(named: 'filePath'),
            authorization: any(named: 'authorization'),
            meta: any(named: 'meta'),
            resumeFromByte: any(named: 'resumeFromByte'),
          ),
        ).thenAnswer((invocation) async {
          enqueued.add(
            invocation.namedArguments[const Symbol('taskId')] as String,
          );
        });
        await repository.getTransfers();

        // Five outages, but the upload has to re-send the whole file each
        // time, so the app stops trying and leaves the decision to a person.
        for (var i = 0; i < 5; i++) {
          online.add(true);
          await settle();
          // The native task picks the transfer up, which is what makes it
          // something an outage can park again.
          if (enqueued.isNotEmpty) {
            taskEvents.add(
              TransferStatusEvent(
                enqueued.last,
                null,
                status: TransferStatus.running,
              ),
            );
          }
          await settle();
          online.add(false);
          await settle();
        }

        expect(enqueued, hasLength(3));
      },
    );

    test(
      'an upload the server already holds in full is completed, not resent',
      () async {
        when(
          () => dao.all(),
        ).thenAnswer((_) async => [upload('a', status: TransferStatus.paused)]);
        when(
          () => resumeProbe.confirmedBytes(
            uploadId: any(named: 'uploadId'),
            totalBytes: any(named: 'totalBytes'),
            transferredBytes: any(named: 'transferredBytes'),
            authorization: any(named: 'authorization'),
          ),
        ).thenAnswer((_) async => 160 * 1024 * 1024);
        await repository.getTransfers();

        final resumed = await repository.resume('a');

        expect(resumed.dataOrNull!.status, TransferStatus.completed);
        verifyNever(
          () => service.enqueueUpload(
            taskId: any(named: 'taskId'),
            filePath: any(named: 'filePath'),
            authorization: any(named: 'authorization'),
            meta: any(named: 'meta'),
            resumeFromByte: any(named: 'resumeFromByte'),
          ),
        );
      },
    );
  });

  group('holding on to the file an upload is reading from', () {
    test('the upload follows the source out of the cache directory', () async {
      const retained = '/data/support/upload_sources/9f_big_video.mp4';
      when(() => dao.all()).thenAnswer((_) async => []);
      when(() => service.retainUploadSource(any()))
          .thenAnswer((_) async => retained);
      when(
        () => service.enqueueUpload(
          taskId: any(named: 'taskId'),
          filePath: any(named: 'filePath'),
          authorization: any(named: 'authorization'),
          meta: any(named: 'meta'),
          resumeFromByte: any(named: 'resumeFromByte'),
        ),
      ).thenAnswer((_) async {});

      final started = await repository.startUpload(
        UploadRequestEntity(
          filePath: source.path,
          fileName: 'big_video.mp4',
          sizeBytes: 500 * 1024 * 1024,
        ),
      );

      // Both the row and the native task point at the durable copy, so a
      // cache purge while the upload waits cannot pull the file out from
      // under it.
      expect(started.dataOrNull!.localPath, retained);
      verify(
        () => service.enqueueUpload(
          taskId: any(named: 'taskId'),
          filePath: retained,
          authorization: any(named: 'authorization'),
          meta: any(named: 'meta'),
          resumeFromByte: any(named: 'resumeFromByte'),
        ),
      ).called(1);
    });

    test('a resync clears sources no transfer is waiting on', () async {
      final waiting = TransferModel(
        id: 'waiting',
        taskId: 'task-waiting',
        type: TransferType.upload,
        fileName: 'waiting.mp4',
        localPath: '/data/support/upload_sources/1_waiting.mp4',
        status: TransferStatus.paused,
        createdAt: now,
        updatedAt: now,
      );
      final finished = TransferModel(
        id: 'finished',
        taskId: 'task-finished',
        type: TransferType.upload,
        fileName: 'finished.mp4',
        localPath: '/data/support/upload_sources/2_finished.mp4',
        status: TransferStatus.completed,
        createdAt: now,
        updatedAt: now,
        progress: 1,
      );
      when(() => dao.all()).thenAnswer((_) async => [waiting, finished]);
      when(service.resumeFromBackground).thenAnswer((_) async {});
      when(() => service.recordedStatus(any())).thenAnswer((_) async => null);
      when(() => service.pruneUploadSources(any())).thenAnswer((_) async {});

      await repository.resync();

      final kept =
          verify(() => service.pruneUploadSources(captureAny())).captured.single
              as Iterable<String>;
      expect(kept, [waiting.localPath]);
    });
  });
}
