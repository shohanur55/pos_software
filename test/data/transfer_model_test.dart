import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/data/models/transfer_events.dart';
import 'package:pos_software/src/data/models/transfer_model.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_pause_reason.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';

void main() {
  final created = DateTime.utc(2026, 11, 13, 10);
  final now = created.add(const Duration(minutes: 1));
  final model = TransferModel(
    id: 'id',
    taskId: 'task',
    type: TransferType.upload,
    fileName: 'a.csv',
    status: TransferStatus.running,
    createdAt: created,
    updatedAt: created,
    totalBytes: 1000,
    localPath: '/tmp/a.csv',
  );

  test('entity always clamps progress', () {
    expect(
      TransferEntity(
        id: 'x',
        type: TransferType.download,
        fileName: 'f',
        status: TransferStatus.running,
        createdAt: created,
        updatedAt: created,
        progress: -5,
      ).progress,
      0,
    );
    expect(
      TransferEntity(
        id: 'x',
        type: TransferType.download,
        fileName: 'f',
        status: TransferStatus.running,
        createdAt: created,
        updatedAt: created,
        progress: 3,
      ).progress,
      1,
    );
  });

  test('progress updates bytes, speed and remaining time', () {
    final next = model.applyProgress(
      const TransferProgressEvent(
        'task',
        null,
        progress: 0.25,
        speedBytesPerSecond: 100,
        timeRemaining: Duration(seconds: 7),
      ),
      now,
    );
    expect(next.progress, 0.25);
    expect(next.transferredBytes, 250);
    expect(next.speedBytesPerSecond, 100);
    expect(next.timeRemaining, const Duration(seconds: 7));
  });

  test('completion fills the bar and clears transient data', () {
    final running = model.copyWith(
      progress: 0.9,
      speedBytesPerSecond: 10,
      timeRemaining: const Duration(seconds: 1),
    );
    final done = running.applyStatus(
      const TransferStatusEvent('task', null, status: TransferStatus.completed),
      now,
    );
    expect(done.status, TransferStatus.completed);
    expect(done.progress, 1);
    expect(done.transferredBytes, 1000);
    expect(done.speedBytesPerSecond, isNull);
    expect(done.timeRemaining, isNull);
  });

  test('failure keeps progress and records the error kind', () {
    final failed = model
        .copyWith(progress: 0.4)
        .applyStatus(
          const TransferStatusEvent(
            'task',
            null,
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.network,
            errorMessage: 'reset',
          ),
          now,
        );
    expect(failed.progress, 0.4);
    expect(failed.errorKind, TransferErrorKind.network);
    expect(failed.errorMessage, 'reset');
  });

  test('a later non-failure status clears a previous error', () {
    final failed = model.copyWith(
      status: TransferStatus.failed,
      errorKind: TransferErrorKind.server,
    );
    final running = failed.applyStatus(
      const TransferStatusEvent('task', null, status: TransferStatus.running),
      now,
    );
    expect(running.errorKind, isNull);
  });

  test('restart resets progress, swaps the task and can carry a notice', () {
    final restarted = model
        .copyWith(progress: 0.7, transferredBytes: 700)
        .restartedWith('task-2', now, notice: TransferErrorKind.resumeFailed);
    expect(restarted.id, 'id');
    expect(restarted.taskId, 'task-2');
    expect(restarted.status, TransferStatus.queued);
    expect(restarted.progress, 0);
    expect(restarted.transferredBytes, 0);
    expect(restarted.errorKind, TransferErrorKind.resumeFailed);
  });

  test('json round trip keeps persisted fields', () {
    final original = model.copyWith(
      status: TransferStatus.failed,
      errorKind: TransferErrorKind.storage,
      remoteFileName: 'a_1.csv',
      savedPath: '/x/a.csv',
      pendingFinalize: true,
      progress: 0.5,
    );
    final restored = TransferModel.fromJson(original.toJson());
    expect(restored, original);
  });

  test('unknown enum names in stored json do not crash', () {
    final json = model.toJson()..['errorKind'] = 'somethingNew';
    expect(TransferModel.fromJson(json).errorKind, isNull);
  });

  group('resuming an upload from an offset', () {
    final paused = model.copyWith(
      status: TransferStatus.paused,
      pauseReason: TransferPauseReason.noNetwork,
      progress: 0.8,
      transferredBytes: 800,
    );

    test('resumedWith keeps the progress already made', () {
      final resumed = paused.resumedWith('task-2', 800, now);

      expect(resumed.taskId, 'task-2');
      expect(resumed.status, TransferStatus.queued);
      expect(resumed.resumeFromByte, 800);
      expect(resumed.transferredBytes, 800);
      expect(resumed.progress, 0.8);
      expect(resumed.pauseReason, isNull);
    });

    test('restartedWith drops the offset, because it starts over', () {
      final restarted = paused.restartedWith('task-2', now);

      expect(restarted.resumeFromByte, 0);
      expect(restarted.transferredBytes, 0);
      expect(restarted.progress, 0);
      expect(restarted.pauseReason, isNull);
    });

    test('progress from a resumed task is rebased onto the whole file', () {
      final resumed = paused.resumedWith('task-2', 800, now);

      // The native task is halfway through the 200 bytes it was given, which
      // is 900 of 1000 bytes of the file — not 50%.
      final ticked = resumed.applyProgress(
        const TransferProgressEvent('task-2', null, progress: 0.5),
        now,
      );

      expect(ticked.progress, 0.9);
      expect(ticked.transferredBytes, 900);
    });

    test(
      'a resumed task reporting only the remainder cannot shrink the file',
      () {
        final resumed = paused.resumedWith('task-2', 800, now);

        final ticked = resumed.applyProgress(
          // 200 bytes is what this task sends, not what the file holds.
          const TransferProgressEvent(
            'task-2',
            null,
            progress: 0.5,
            expectedBytes: 200,
          ),
          now,
        );

        expect(ticked.totalBytes, 1000);
      },
    );

    test('an ordinary upload is unaffected by the rebasing', () {
      final ticked = model.applyProgress(
        const TransferProgressEvent('task', null, progress: 0.25),
        now,
      );

      expect(ticked.progress, 0.25);
      expect(ticked.transferredBytes, 250);
    });

    test('the pause reason survives a round trip through storage', () {
      final restored = TransferModel.fromJson(paused.toJson());

      expect(restored.pauseReason, TransferPauseReason.noNetwork);
      expect(restored.isWaitingForNetwork, isTrue);
    });

    test('an unknown pause reason in stored json does not crash', () {
      final json = paused.toJson()..['pauseReason'] = 'somethingNew';

      expect(TransferModel.fromJson(json).pauseReason, isNull);
    });
  });
}
