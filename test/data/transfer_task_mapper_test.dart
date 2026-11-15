import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/data/models/transfer_events.dart';
import 'package:pos_software/src/data/models/transfer_task_mapper.dart';
import 'package:pos_software/src/data/models/transfer_task_meta.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';

void main() {
  final meta = TransferTaskMeta(
    transferId: 't1',
    type: TransferType.download,
    displayName: 'a.csv',
    createdAt: DateTime.utc(2026, 11, 13),
  );
  DownloadTask task() => DownloadTask(
    taskId: 'task-1',
    url: 'http://host/get?file=a.csv',
    filename: 'a.csv',
    metaData: meta.encode(),
  );

  group('status', () {
    test('maps every native status', () {
      expect(
        TransferTaskMapper.status(TaskStatus.enqueued),
        TransferStatus.queued,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.running),
        TransferStatus.running,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.complete),
        TransferStatus.completed,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.failed),
        TransferStatus.failed,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.notFound),
        TransferStatus.failed,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.canceled),
        TransferStatus.canceled,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.waitingToRetry),
        TransferStatus.waitingToRetry,
      );
      expect(
        TransferTaskMapper.status(TaskStatus.paused),
        TransferStatus.paused,
      );
    });
  });

  group('progress sentinels', () {
    test('map negative values to a status', () {
      expect(
        TransferTaskMapper.statusFromProgress(progressFailed),
        TransferStatus.failed,
      );
      expect(
        TransferTaskMapper.statusFromProgress(progressCanceled),
        TransferStatus.canceled,
      );
      expect(
        TransferTaskMapper.statusFromProgress(progressNotFound),
        TransferStatus.failed,
      );
      expect(
        TransferTaskMapper.statusFromProgress(progressWaitingToRetry),
        TransferStatus.waitingToRetry,
      );
      expect(
        TransferTaskMapper.statusFromProgress(progressPaused),
        TransferStatus.paused,
      );
      expect(TransferTaskMapper.statusFromProgress(0.4), isNull);
    });

    test('progress is always clamped to 0..1', () {
      expect(TransferTaskMapper.clampProgress(-5), 0);
      expect(TransferTaskMapper.clampProgress(1.2), 1);
      expect(TransferTaskMapper.clampProgress(0.25), 0.25);
    });

    test('a paused sentinel becomes a status event, never "-5%"', () {
      final event = TransferTaskMapper.fromProgressUpdate(
        TaskProgressUpdate(task(), progressPaused),
      );
      expect(
        event,
        isA<TransferStatusEvent>().having(
          (event) => event.status,
          'status',
          TransferStatus.paused,
        ),
      );
    });

    test('regular progress keeps size, speed and time', () {
      final event = TransferTaskMapper.fromProgressUpdate(
        TaskProgressUpdate(task(), 0.5, 1000, 2.0, const Duration(seconds: 20)),
      );
      expect(event, isA<TransferProgressEvent>());
      final progress = event as TransferProgressEvent;
      expect(progress.progress, 0.5);
      expect(progress.expectedBytes, 1000);
      expect(progress.speedBytesPerSecond, 2000000);
      expect(progress.timeRemaining, const Duration(seconds: 20));
      expect(progress.meta?.transferId, 't1');
    });

    test('unknown size, speed and time become null', () {
      final event = TransferTaskMapper.fromProgressUpdate(
        TaskProgressUpdate(task(), 0.1),
      ) as TransferProgressEvent;
      expect(event.expectedBytes, isNull);
      expect(event.speedBytesPerSecond, isNull);
      expect(event.timeRemaining, isNull);
    });
  });

  group('error kinds', () {
    TransferErrorKind? kind(
      TaskException exception, [
      TransferType type = TransferType.download,
    ]) => TransferTaskMapper.errorKind(TaskStatus.failed, exception, type);

    test('maps HTTP codes', () {
      expect(kind(TaskHttpException('x', 401)), TransferErrorKind.unauthorized);
      expect(kind(TaskHttpException('x', 404)), TransferErrorKind.notFound);
      expect(kind(TaskHttpException('x', 413)), TransferErrorKind.fileTooLarge);
      expect(kind(TaskHttpException('x', 400)), TransferErrorKind.invalidFile);
      expect(kind(TaskHttpException('x', 415)), TransferErrorKind.invalidFile);
      expect(kind(TaskHttpException('x', 422)), TransferErrorKind.invalidFile);
      expect(kind(TaskHttpException('x', 503)), TransferErrorKind.server);
      expect(kind(TaskHttpException('x', 418)), TransferErrorKind.unknown);
    });

    test('maps exception types', () {
      expect(kind(TaskConnectionException('x')), TransferErrorKind.network);
      expect(kind(TaskResumeException('x')), TransferErrorKind.resumeFailed);
      expect(kind(TaskFileSystemException('x')), TransferErrorKind.storage);
      expect(
        kind(TaskFileSystemException('x'), TransferType.upload),
        TransferErrorKind.invalidFile,
      );
      expect(kind(TaskUrlException('x')), TransferErrorKind.unknown);
    });

    test('notFound status is reported as notFound', () {
      expect(
        TransferTaskMapper.errorKind(
          TaskStatus.notFound,
          null,
          TransferType.download,
        ),
        TransferErrorKind.notFound,
      );
    });

    test('non-failure statuses have no error', () {
      expect(
        TransferTaskMapper.errorKind(
          TaskStatus.complete,
          null,
          TransferType.download,
        ),
        isNull,
      );
    });
  });

  test('status update carries meta, error and response body', () {
    final event = TransferTaskMapper.fromStatusUpdate(
      TaskStatusUpdate(
        task(),
        TaskStatus.failed,
        TaskHttpException('Unauthorized', 401),
        '{"error":1}',
      ),
    );
    expect(event.status, TransferStatus.failed);
    expect(event.errorKind, TransferErrorKind.unauthorized);
    expect(event.meta?.transferId, 't1');
    expect(event.responseBody, '{"error":1}');
  });

  test(
    'task meta survives an encode/decode round trip and rejects foreign data',
    () {
      final decoded = TransferTaskMeta.tryDecode(meta.encode());
      expect(decoded?.transferId, 't1');
      expect(decoded?.type, TransferType.download);
      expect(TransferTaskMeta.tryDecode(''), isNull);
      expect(TransferTaskMeta.tryDecode('custom_id_123'), isNull);
      expect(TransferTaskMeta.tryDecode('{"type":"other"}'), isNull);
    },
  );
}
