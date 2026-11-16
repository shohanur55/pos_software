import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/domain/entities/auth_session_entity.dart';
import 'package:pos_software/src/domain/entities/remote_file_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/presentation/app.dart';
import 'package:pos_software/src/presentation/pages/shell/widgets/transfer_mini_banner.dart';
import 'package:pos_software/src/presentation/widgets/transfer/transfer_progress_bar.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// The download module, driven through the real UI: a file in the list, the
/// button that fetches it, the progress on the row and in the dashboard, and
/// what the operator is offered when it finishes or fails.
void main() {
  const report = RemoteFileEntity(
    name: 'report.csv',
    // The address the list endpoint returned, which is what the download has
    // to use — not one the app guessed from the name.
    url: 'http://server.test:90/get?file=report.csv',
    sizeBytes: 8 * 1024 * 1024,
  );

  late TestApp app;

  setUpAll(() => registerFallbackValue(report));

  setUp(() => app = TestApp());

  AuthSessionEntity liveSession() =>
      session(expiresAt: DateTime.now().add(const Duration(hours: 1)));

  TransferEntity download({
    required TransferStatus status,
    double progress = 0,
    TransferErrorKind? errorKind,
    String? savedPath,
  }) => transfer(
    id: 'dl-1',
    type: TransferType.download,
    status: status,
    progress: progress,
    fileName: 'report.csv',
    remoteFileName: 'report.csv',
    totalBytes: 8 * 1024 * 1024,
    errorKind: errorKind,
    savedPath: savedPath,
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await tester.pump();
  }

  Future<void> openFiles(
    WidgetTester tester, {
    List<TransferEntity> history = const [],
  }) async {
    tester.view
      ..physicalSize = const Size(400, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await app.register(
      session: liveSession(),
      remoteFiles: const [report],
      history: history,
    );
    await app.start();
    await tester.pumpWidget(const PosApp());
    await settle(tester);
    await tester.tap(find.text('Files').last);
    await settle(tester);
  }

  testWidgets('a listed file offers a download, using the API\'s own URL', (
    tester,
  ) async {
    when(
      () => app.transfers.startDownload(any()),
    ).thenAnswer((_) async => Success(download(status: TransferStatus.queued)));
    await openFiles(tester);

    expect(find.text('report.csv'), findsOneWidget);
    await tester.tap(find.byTooltip('Download'));
    await settle(tester);

    final requested =
        verify(() => app.transfers.startDownload(captureAny())).captured.single
            as RemoteFileEntity;
    expect(requested.url, 'http://server.test:90/get?file=report.csv');
    await finish(tester);
  });

  testWidgets('progress shows on the file row while it runs', (tester) async {
    await openFiles(
      tester,
      history: [download(status: TransferStatus.running, progress: 0.42)],
    );

    // The bar and the figure sit on the row the operator tapped, not only in
    // the dashboard they would have to go and find.
    expect(find.byType(TransferProgressBar), findsWidgets);
    expect(find.text('42%'), findsWidgets);
    // Running, so the row's action becomes Pause.
    expect(find.byTooltip('Pause'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a running download is visible from another tab', (tester) async {
    await openFiles(
      tester,
      history: [download(status: TransferStatus.running, progress: 0.42)],
    );
    await tester.tap(find.text('Upload').last);
    await settle(tester);

    // The persistent banner follows the operator around the app.
    expect(find.byType(TransferMiniBanner), findsOneWidget);
    expect(find.textContaining('1 transfer in progress'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('the dashboard lists it with its status and progress', (
    tester,
  ) async {
    await openFiles(
      tester,
      history: [download(status: TransferStatus.running, progress: 0.42)],
    );
    await tester.tap(find.text('Transfers').last);
    await settle(tester);

    expect(find.text('Downloading'), findsOneWidget);
    expect(find.text('42%'), findsWidgets);
    await finish(tester);
  });

  testWidgets('a finished download says where the file went', (tester) async {
    await openFiles(
      tester,
      history: [
        download(
          status: TransferStatus.completed,
          progress: 1,
          savedPath: '/storage/emulated/0/Download/POS Software/report.csv',
        ),
      ],
    );

    // The row now offers to open it rather than fetch it again.
    expect(find.byTooltip('Open'), findsOneWidget);
    await tester.tap(find.text('Transfers').last);
    await settle(tester);

    expect(
      find.textContaining('Download/POS Software/report.csv'),
      findsOneWidget,
    );
    await finish(tester);
  });

  group('when it goes wrong', () {
    testWidgets('a dead network explains itself and offers a retry', (
      tester,
    ) async {
      when(() => app.transfers.retry(any())).thenAnswer(
        (_) async => Success(download(status: TransferStatus.queued)),
      );
      await openFiles(
        tester,
        history: [
          download(
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.network,
          ),
        ],
      );

      expect(find.byTooltip('Retry'), findsOneWidget);
      await tester.tap(find.text('Transfers').last);
      await settle(tester);
      expect(
        find.text(
          "Can't reach the server. Check your internet connection and try "
          'again.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.byTooltip('Retry').first);
      await settle(tester);
      verify(() => app.transfers.retry('dl-1')).called(1);
      await finish(tester);
    });

    testWidgets('a server fault never shows a status code', (tester) async {
      await openFiles(
        tester,
        history: [
          download(
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.server,
          ),
        ],
      );
      await tester.tap(find.text('Transfers').last);
      await settle(tester);

      expect(
        find.text(
          'The server ran into a problem. Please try again in a moment.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('500'), findsNothing);
      await finish(tester);
    });

    testWidgets('a file that is gone from the server says so', (tester) async {
      await openFiles(
        tester,
        history: [
          download(
            status: TransferStatus.failed,
            errorKind: TransferErrorKind.notFound,
          ),
        ],
      );
      await tester.tap(find.text('Transfers').last);
      await settle(tester);

      expect(
        find.text('This file is no longer on the server.'),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('asking for a download twice is refused, not duplicated', (
      tester,
    ) async {
      when(() => app.transfers.startDownload(any())).thenAnswer(
        (_) async => const Error(Failure(FailureKind.alreadyInProgress, '')),
      );
      await openFiles(
        tester,
        history: [download(status: TransferStatus.paused, progress: 0.2)],
      );

      // Paused, so the row offers to continue it rather than start again.
      expect(find.byTooltip('Resume'), findsOneWidget);
      verifyNever(() => app.transfers.startDownload(any()));
      await finish(tester);
    });
  });
}
