import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_pause_reason.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/domain/usecases/transfers/cancel_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/clear_finished_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/get_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/open_transfer_file_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/pause_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/remove_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/resume_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/resync_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/retry_transfer_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/start_download_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/watch_transfers_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/watch_upload_resume_support_use_case.dart';
import 'package:pos_software/src/presentation/blocs/transfer/transfer_bloc.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockTransferRepository repository;
  late StreamController<TransferEntity> updates;
  late StreamController<String> removed;
  late StreamController<bool?> resumeSupport;

  setUpAll(() => registerFallbackValue(remoteCsv));

  setUp(() {
    repository = MockTransferRepository();
    updates = StreamController<TransferEntity>.broadcast();
    removed = StreamController<String>.broadcast();
    resumeSupport = StreamController<bool?>.broadcast();
    when(() => repository.watchTransfers()).thenAnswer((_) => updates.stream);
    when(() => repository.watchRemovedTransfers())
        .thenAnswer((_) => removed.stream);
    when(() => repository.watchUploadResumeSupport())
        .thenAnswer((_) => resumeSupport.stream);
    when(() => repository.uploadResumeSupport).thenReturn(null);
    when(() => repository.getTransfers())
        .thenAnswer((_) async => const Success([]));
  });

  tearDown(() async {
    await updates.close();
    await removed.close();
    await resumeSupport.close();
  });

  TransferBloc build() => TransferBloc(
    getTransfers: GetTransfersUseCase(repository),
    watchTransfers: WatchTransfersUseCase(repository),
    watchUploadResumeSupport: WatchUploadResumeSupportUseCase(repository),
    resyncTransfers: ResyncTransfersUseCase(repository),
    startDownload: StartDownloadUseCase(repository),
    pauseTransfer: PauseTransferUseCase(repository),
    resumeTransfer: ResumeTransferUseCase(repository),
    cancelTransfer: CancelTransferUseCase(repository),
    retryTransfer: RetryTransferUseCase(repository),
    removeTransfer: RemoveTransferUseCase(repository),
    clearFinished: ClearFinishedTransfersUseCase(repository),
    openFile: OpenTransferFileUseCase(repository),
  );

  final oldDone = transfer(
    id: 'done',
    status: TransferStatus.completed,
    progress: 1,
    createdAt: fixedNow.subtract(const Duration(hours: 2)),
  );
  final newFailed = transfer(
    id: 'failed',
    status: TransferStatus.failed,
    createdAt: fixedNow.subtract(const Duration(hours: 1)),
  );
  final oldRunning = transfer(
    id: 'running',
    createdAt: fixedNow.subtract(const Duration(hours: 3)),
  );

  group('history', () {
    blocTest<TransferBloc, TransferState>(
      'loads history with active first, then newest first, and treats old failures as seen',
      setUp: () => when(() => repository.getTransfers())
          .thenAnswer((_) async => Success([oldDone, newFailed, oldRunning])),
      build: build,
      act: (bloc) => bloc.add(const TransfersStarted()),
      expect: () => [
        const TransferState(status: TransferListStatus.loading),
        TransferState(
          status: TransferListStatus.ready,
          transfers: [oldRunning, newFailed, oldDone],
          acknowledgedFailureIds: const {'failed'},
        ),
      ],
    );

    blocTest<TransferBloc, TransferState>(
      'shows a failure status when history cannot be read',
      setUp: () => when(() => repository.getTransfers())
          .thenAnswer((_) async => const Error(Failure(FailureKind.storage))),
      build: build,
      act: (bloc) => bloc.add(const TransfersStarted()),
      expect: () => [
        const TransferState(status: TransferListStatus.loading),
        const TransferState(status: TransferListStatus.failure),
      ],
    );
  });

  group('live updates', () {
    blocTest<TransferBloc, TransferState>(
      'applies progress updates in place',
      setUp: () =>
          when(() => repository.getTransfers())
              .thenAnswer((_) async => Success([oldRunning])),
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        updates.add(
          transfer(
            id: 'running',
            progress: 0.8,
            createdAt: oldRunning.createdAt,
          ),
        );
      },
      skip: 2,
      expect: () => [
        isA<TransferState>()
            .having((state) => state.byId('running')?.progress, 'progress', 0.8)
            .having((state) => state.transfers.length, 'length', 1),
      ],
    );

    blocTest<TransferBloc, TransferState>(
      'announces a completed upload once',
      setUp: () =>
          when(() => repository.getTransfers())
              .thenAnswer((_) async => Success([oldRunning])),
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        final done = transfer(
          id: 'running',
          status: TransferStatus.completed,
          progress: 1,
          createdAt: oldRunning.createdAt,
        );
        updates
          ..add(done)
          ..add(done);
      },
      skip: 2,
      expect: () => [
        isA<TransferState>()
            .having(
              (state) => state.notice?.kind,
              'notice',
              TransferNoticeKind.uploadCompleted,
            )
            .having((state) => state.notice?.subject, 'subject', 'catalog.csv'),
      ],
    );

    blocTest<TransferBloc, TransferState>(
      'turns a 401 failure into an unauthorized notice',
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        updates.add(
          transfer(
            id: 'x',
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.unauthorized,
          ),
        );
      },
      skip: 2,
      expect: () => [
        isA<TransferState>().having(
          (state) => state.notice?.kind,
          'notice',
          TransferNoticeKind.unauthorized,
        ),
      ],
    );

    blocTest<TransferBloc, TransferState>(
      'drops removed transfers',
      setUp: () =>
          when(() => repository.getTransfers())
              .thenAnswer((_) async => Success([oldDone])),
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        removed.add('done');
      },
      skip: 2,
      expect: () => [
        isA<TransferState>().having(
          (state) => state.transfers,
          'transfers',
          isEmpty,
        ),
      ],
    );
  });

  group('actions', () {
    blocTest<TransferBloc, TransferState>(
      'pause, cancel and retry delegate to the repository',
      setUp: () {
        when(() => repository.pause(any()))
            .thenAnswer((_) async => const Success(null));
        when(() => repository.cancel(any()))
            .thenAnswer((_) async => const Success(null));
        when(() => repository.retry(any()))
            .thenAnswer((_) async => Success(transfer()));
      },
      build: build,
      act: (bloc) => bloc
        ..add(const TransferPaused('a'))
        ..add(const TransferCanceled('b'))
        ..add(const TransferRetried('c')),
      expect: () => <TransferState>[],
      verify: (_) {
        verify(() => repository.pause('a')).called(1);
        verify(() => repository.cancel('b')).called(1);
        verify(() => repository.retry('c')).called(1);
      },
    );

    blocTest<TransferBloc, TransferState>(
      'resume that had to restart tells the user',
      setUp: () => when(() => repository.resume('d')).thenAnswer(
        (_) async => Success(
          transfer(
            id: 'd',
            type: TransferType.download,
            status: TransferStatus.queued,
            errorKind: TransferErrorKind.resumeFailed,
          ),
        ),
      ),
      build: build,
      act: (bloc) => bloc.add(const TransferResumed('d')),
      expect: () => [
        isA<TransferState>().having(
          (state) => state.notice?.kind,
          'notice',
          TransferNoticeKind.resumeRestarting,
        ),
      ],
    );

    blocTest<TransferBloc, TransferState>(
      'failed actions surface a friendly notice',
      setUp: () => when(
        () => repository.pause('a'),
      ).thenAnswer((_) async => const Error(Failure(FailureKind.notAllowed))),
      build: build,
      act: (bloc) => bloc.add(const TransferPaused('a')),
      expect: () => [
        isA<TransferState>()
            .having(
              (state) => state.notice?.kind,
              'kind',
              TransferNoticeKind.actionFailed,
            )
            .having(
              (state) => state.notice?.failure,
              'failure',
              FailureKind.notAllowed,
            ),
      ],
    );

    blocTest<TransferBloc, TransferState>(
      'does not start a second download of the same file',
      build: build,
      seed: () => TransferState(
        status: TransferListStatus.ready,
        transfers: [
          transfer(
            id: 'dl',
            type: TransferType.download,
            remoteFileName: 'catalog.csv',
          ),
        ],
      ),
      act: (bloc) => bloc.add(const DownloadStarted(remoteCsv)),
      expect: () => [
        isA<TransferState>().having(
          (state) => state.notice?.kind,
          'notice',
          TransferNoticeKind.alreadyDownloading,
        ),
      ],
      verify: (_) => verifyNever(() => repository.startDownload(any())),
    );

    blocTest<TransferBloc, TransferState>(
      'starts a download and confirms it',
      setUp: () => when(
        () => repository.startDownload(remoteCsv),
      ).thenAnswer((_) async => Success(transfer(type: TransferType.download))),
      build: build,
      act: (bloc) => bloc.add(const DownloadStarted(remoteCsv)),
      expect: () => [
        isA<TransferState>().having(
          (state) => state.notice?.kind,
          'notice',
          TransferNoticeKind.downloadStarted,
        ),
      ],
    );
  });

  group('derived getters', () {
    final state = TransferState(
      transfers: [
        transfer(id: 'a', progress: 0.2),
        transfer(
          id: 'b',
          status: TransferStatus.paused,
          progress: 0.6,
          type: TransferType.download,
          remoteFileName: 'catalog.csv',
        ),
        transfer(id: 'c', status: TransferStatus.failed),
        transfer(id: 'd', status: TransferStatus.completed, progress: 1),
      ],
      acknowledgedFailureIds: const {},
    );

    test('count and average in-progress transfers', () {
      expect(state.activeCount, 2);
      expect(state.overallProgress, closeTo(0.4, 1e-9));
      expect(state.failedCount, 1);
      expect(state.unseenFailedCount, 1);
      expect(state.completedCount, 1);
      expect(state.finishedCount, 2);
    });

    test('look transfers up by id and remote name', () {
      expect(state.byId('c')?.status, TransferStatus.failed);
      expect(state.byId('missing'), isNull);
      expect(state.activeDownloadFor('catalog.csv')?.id, 'b');
      expect(state.latestDownloadFor('catalog.csv')?.id, 'b');
      expect(state.activeDownloadFor('other.csv'), isNull);
    });

    test('overall progress is zero with nothing active', () {
      expect(const TransferState().overallProgress, 0);
    });
  });

  blocTest<TransferBloc, TransferState>(
    'acknowledging failures hides them from the banner',
    build: build,
    seed: () => TransferState(transfers: [newFailed]),
    act: (bloc) => bloc.add(const TransferFailuresAcknowledged()),
    expect: () => [
      TransferState(
        transfers: [newFailed],
        acknowledgedFailureIds: const {'failed'},
      ),
    ],
    verify: (bloc) => expect(bloc.state.unseenFailedCount, 0),
  );

  group('what the operator is told about the network', () {
    final running = transfer(
      id: 'big',
      type: TransferType.download,
      status: TransferStatus.running,
      fileName: 'catalog_full.csv',
      totalBytes: 1000,
      progress: 0.8,
      canPauseNatively: true,
    );
    final parked = transfer(
      id: 'big',
      type: TransferType.download,
      status: TransferStatus.paused,
      fileName: 'catalog_full.csv',
      totalBytes: 1000,
      progress: 0.8,
      canPauseNatively: true,
      pauseReason: TransferPauseReason.noNetwork,
    );

    blocTest<TransferBloc, TransferState>(
      'a transfer parked by a dropped connection says so',
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        updates
          ..add(running)
          ..add(parked);
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.notice?.kind, TransferNoticeKind.pausedByNetwork);
        expect(bloc.state.notice?.subject, 'catalog_full.csv');
      },
    );

    blocTest<TransferBloc, TransferState>(
      'coming back online names the position the transfer picks up from',
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        updates
          ..add(parked)
          ..add(running);
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.notice?.kind, TransferNoticeKind.resumedFromOffset);
        expect(bloc.state.notice?.detail, '800 B');
      },
    );

    blocTest<TransferBloc, TransferState>(
      'an upload that has to start over is not promised a position',
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        final pausedUpload = transfer(
          id: 'up',
          status: TransferStatus.paused,
          pauseReason: TransferPauseReason.noNetwork,
        );
        updates
          ..add(pausedUpload)
          ..add(transfer(id: 'up', status: TransferStatus.queued));
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.notice?.kind, TransferNoticeKind.autoResumed);
      },
    );
  });

  group('what the server can do with an interrupted upload', () {
    blocTest<TransferBloc, TransferState>(
      'starts out unknown, so nothing is claimed about the server',
      build: build,
      verify: (bloc) {
        expect(bloc.state.uploadResumeSupported, isNull);
        expect(bloc.state.uploadsRestartFromStart, isFalse);
      },
    );

    blocTest<TransferBloc, TransferState>(
      'picks up the answer once the server gives one',
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        resumeSupport.add(false);
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.uploadResumeSupported, isFalse);
        expect(bloc.state.uploadsRestartFromStart, isTrue);
      },
    );

    blocTest<TransferBloc, TransferState>(
      'an endpoint that can resume is not warned about',
      build: build,
      act: (bloc) async {
        bloc.add(const TransfersStarted());
        await Future<void>.delayed(Duration.zero);
        resumeSupport.add(true);
      },
      wait: const Duration(milliseconds: 10),
      verify: (bloc) => expect(bloc.state.uploadsRestartFromStart, isFalse),
    );
  });
}
