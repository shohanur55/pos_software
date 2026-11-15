import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/core/di/dependency_injection.dart';
import 'package:pos_software/src/domain/entities/notification_permission_status.dart';
import 'package:pos_software/src/domain/entities/picked_file_entity.dart';
import 'package:pos_software/src/domain/entities/remote_file_entity.dart';
import 'package:pos_software/src/domain/entities/remote_files_snapshot.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/domain/entities/upload_request_entity.dart';
import 'package:pos_software/src/presentation/app.dart';
import 'package:pos_software/src/presentation/blocs/connectivity/connectivity_cubit.dart';
import 'package:pos_software/src/presentation/pages/shell/widgets/transfer_mini_banner.dart';
import 'package:pos_software/src/presentation/router/router.dart';
import 'package:pos_software/src/presentation/router/routes.dart';
import 'package:pos_software/src/presentation/widgets/common/shimmer.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Drives the real app with mocked repositories, covering the paths a POS
/// terminal hits daily: no network, a flaky server, and a reconnect.
void main() {
  const catalog = RemoteFileEntity(
    name: 'catalog.csv',
    url: 'http://server.test:90/get?file=catalog.csv',
    sizeBytes: 2048,
  );
  const picked = PickedFileEntity(
    path: '/tmp/catalog.csv',
    name: 'catalog.csv',
    sizeBytes: 2048,
    extension: 'csv',
  );

  late TestApp app;

  setUpAll(() {
    registerFallbackValue(catalog);
    registerFallbackValue(
      const UploadRequestEntity(filePath: '', fileName: '', sizeBytes: 0),
    );
  });

  setUp(() => app = TestApp());

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

  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(400, 900),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await app.start();
    await tester.pumpWidget(const PosApp());
    await settle(tester);
  }

  group('Login screen', () {
    testWidgets('the server address opens the web portal', (tester) async {
      await app.register();

      await launch(tester);

      await tester.tap(find.text('http://server.test:90'));
      await settle(tester);

      verify(() => app.auth.openRegistrationPortal()).called(1);
      await finish(tester);
    });

    testWidgets('falls back to the address in text when no browser opens', (
      tester,
    ) async {
      await app.register();
      when(
        () => app.auth.openRegistrationPortal(),
      ).thenAnswer((_) async => const Error(Failure(FailureKind.cannotOpen)));

      await launch(tester);
      await tester.tap(find.text('http://server.test:90'));
      await settle(tester);

      expect(
        find.textContaining('Visit http://server.test:90'),
        findsOneWidget,
      );
      await finish(tester);
    });
  });

  group('Files tab', () {
    testWidgets('shows a shimmer skeleton while the first list loads', (
      tester,
    ) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      // Hold the refresh open so the loading state stays on screen.
      when(() => app.files.refreshFiles())
          .thenAnswer((_) => Completer<RemoteFilesSnapshotResult>().future);

      await launch(tester);
      sl<AppRouter>().router.go(Routes.files);
      await settle(tester);

      expect(find.byType(Shimmer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await finish(tester);
    });

    testWidgets(
      'falls back to the offline copy when the server is unreachable',
      (tester) async {
        await app.register(
          session: session(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          remoteFiles: const [catalog],
        );
        when(() => app.files.refreshFiles())
            .thenAnswer((_) async => const Error(Failure(FailureKind.network)));

        await launch(tester);
        sl<AppRouter>().router.go(Routes.files);
        await settle(tester);

        expect(
          find.text('catalog.csv'),
          findsOneWidget,
          reason: 'cached file is listed',
        );
        expect(find.text('Offline copy'), findsOneWidget);
        await finish(tester);
      },
    );

    testWidgets('reports a real failure only when nothing is cached', (
      tester,
    ) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      when(() => app.files.getCachedFiles())
          .thenAnswer((_) async => const Success(RemoteFilesSnapshot.empty()));
      when(() => app.files.refreshFiles())
          .thenAnswer((_) async => const Error(Failure(FailureKind.network)));

      await launch(tester);
      sl<AppRouter>().router.go(Routes.files);
      await settle(tester);

      expect(
        find.text(
          "Can't reach the server. Check your internet connection and try again.",
        ),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('a snack bar never covers the transfer banner', (tester) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        remoteFiles: const [catalog],
        history: [transfer(id: 'running', status: TransferStatus.running)],
      );
      when(() => app.files.deleteFile('catalog.csv'))
          .thenAnswer((_) async => const Success(null));

      await launch(tester);
      sl<AppRouter>().router.go(Routes.files);
      await settle(tester);

      await tester.tap(find.byTooltip('More options').first);
      await settle(tester);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      final banner = tester.getRect(find.byType(TransferMiniBanner));
      final snack = tester.getRect(find.byType(SnackBar));
      expect(
        snack.bottom,
        lessThanOrEqualTo(banner.top),
        reason: 'the running-transfer summary stays readable',
      );
      await finish(tester);
    });

    testWidgets('deleting removes the row straight away', (tester) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        remoteFiles: const [catalog],
      );
      when(() => app.files.deleteFile('catalog.csv'))
          .thenAnswer((_) async => const Success(null));

      await launch(tester);
      sl<AppRouter>().router.go(Routes.files);
      await settle(tester);

      await tester.tap(find.byTooltip('More options').first);
      await settle(tester);
      await tester.tap(find.text('Delete').last);
      await settle(tester);
      expect(find.text('Delete file?'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await settle(tester);

      expect(find.text('catalog.csv'), findsNothing);
      verify(() => app.files.deleteFile('catalog.csv')).called(1);
      await finish(tester);
    });
  });

  group('offline and reconnect', () {
    testWidgets(
      'warns while offline and recovers transfers when the network returns',
      (tester) async {
        final failed = transfer(
          id: 'dead',
          status: TransferStatus.failed,
          type: TransferType.download,
          errorKind: TransferErrorKind.network,
        );
        await app.register(
          session: session(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          remoteFiles: const [catalog],
          history: [failed],
          online: false,
        );
        when(() => app.transfers.retry('dead'))
            .thenAnswer((_) async => Success(failed));

        await launch(tester);
        expect(
          find.text(
            "You're offline. Transfers will continue when the connection is back.",
          ),
          findsOneWidget,
        );

        sl<ConnectivityCubit>().emit(ConnectivityStatus.online);
        await settle(tester);

        verify(() => app.transfers.retry('dead')).called(1);
        verify(() => app.files.refreshFiles()).called(greaterThan(1));
        await finish(tester);
      },
    );

    testWidgets('retries a failed transfer only once per outage', (
      tester,
    ) async {
      final failed = transfer(
        id: 'dead',
        status: TransferStatus.failed,
        errorKind: TransferErrorKind.network,
      );
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        history: [failed],
        online: false,
      );
      when(() => app.transfers.retry('dead'))
          .thenAnswer((_) async => Success(failed));

      await launch(tester);
      final cubit = sl<ConnectivityCubit>();
      for (var i = 0; i < 3; i++) {
        cubit.emit(ConnectivityStatus.offline);
        await tester.pump();
        cubit.emit(ConnectivityStatus.online);
        await settle(tester);
      }

      verify(() => app.transfers.retry('dead')).called(1);
      await finish(tester);
    });

    testWidgets('does not auto-retry a transfer the user canceled', (
      tester,
    ) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        history: [transfer(id: 'stopped', status: TransferStatus.canceled)],
        online: false,
      );

      await launch(tester);
      sl<ConnectivityCubit>().emit(ConnectivityStatus.online);
      await settle(tester);

      verifyNever(() => app.transfers.retry(any()));
      await finish(tester);
    });
  });

  group('Upload tab', () {
    testWidgets('blocks an oversize file with a clear message', (tester) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      when(() => app.picker.pickUploadFile()).thenAnswer((_) async => picked);
      when(() => app.inspector.exists(any())).thenAnswer((_) async => true);
      when(() => app.inspector.isReadable(any())).thenAnswer((_) async => true);
      when(() => app.inspector.length(any()))
          .thenAnswer((_) async => 600 * 1024 * 1024);

      await launch(tester);
      await tester.tap(find.text('Choose file'));
      await settle(tester);

      expect(
        find.text('This file is larger than the 512 MB limit.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Upload'))
            .onPressed,
        isNull,
      );
      verifyNever(() => app.transfers.startUpload(any()));
      await finish(tester);
    });

    testWidgets('asks for notification permission before the first upload', (
      tester,
    ) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        permission: NotificationPermissionStatus.notRequested,
      );
      when(() => app.picker.pickUploadFile()).thenAnswer((_) async => picked);
      when(() => app.inspector.exists(any())).thenAnswer((_) async => true);
      when(() => app.inspector.isReadable(any())).thenAnswer((_) async => true);
      when(() => app.inspector.length(any())).thenAnswer((_) async => 2048);
      when(() => app.transfers.requestNotificationPermission()).thenAnswer(
        (_) async => const Success(NotificationPermissionStatus.granted),
      );
      when(() => app.transfers.startUpload(any()))
          .thenAnswer((_) async => Success(transfer(id: 'up-1')));

      await launch(tester);
      await tester.tap(find.text('Choose file'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Upload'));
      await settle(tester);

      expect(find.text('Show transfer progress?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
      await settle(tester);

      verify(() => app.transfers.requestNotificationPermission()).called(1);
      verify(
        () => app.transfers.startUpload(
          const UploadRequestEntity(
            filePath: '/tmp/catalog.csv',
            fileName: 'catalog.csv',
            sizeBytes: 2048,
          ),
        ),
      ).called(1);
      await finish(tester);
    });

    testWidgets('declining notifications still starts the upload', (
      tester,
    ) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
        permission: NotificationPermissionStatus.notRequested,
      );
      when(() => app.picker.pickUploadFile()).thenAnswer((_) async => picked);
      when(() => app.inspector.exists(any())).thenAnswer((_) async => true);
      when(() => app.inspector.isReadable(any())).thenAnswer((_) async => true);
      when(() => app.inspector.length(any())).thenAnswer((_) async => 2048);
      when(() => app.transfers.startUpload(any()))
          .thenAnswer((_) async => Success(transfer(id: 'up-1')));

      await launch(tester);
      await tester.tap(find.text('Choose file'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Upload'));
      await settle(tester);
      await tester.tap(find.text('Not now'));
      await settle(tester);

      verifyNever(() => app.transfers.requestNotificationPermission());
      verify(() => app.transfers.startUpload(any())).called(1);
      expect(
        find.text(
          "Notifications are off, so you won't see progress in the status bar.",
        ),
        findsOneWidget,
      );
      await finish(tester);
    });

    testWidgets('live progress reaches the Upload tab and the shell banner', (
      tester,
    ) async {
      await app.register(
        session: session(
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
      when(() => app.picker.pickUploadFile()).thenAnswer((_) async => picked);
      when(() => app.inspector.exists(any())).thenAnswer((_) async => true);
      when(() => app.inspector.isReadable(any())).thenAnswer((_) async => true);
      when(() => app.inspector.length(any())).thenAnswer((_) async => 2048);
      when(() => app.transfers.startUpload(any())).thenAnswer(
        (_) async => Success(
          transfer(id: 'up-1', status: TransferStatus.queued, progress: 0),
        ),
      );

      await launch(tester);
      await tester.tap(find.text('Choose file'));
      await settle(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Upload'));
      await settle(tester);

      app.updates.add(transfer(id: 'up-1', progress: 0.5, totalBytes: 2048));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('50%'), findsOneWidget);
      expect(find.text('1.0 KB / 2.0 KB'), findsOneWidget);
      expect(find.textContaining('1 transfer in progress'), findsOneWidget);
      await finish(tester);
    });
  });

  testWidgets('a transfer that fails with 401 sends the user back to login', (
    tester,
  ) async {
    await app.register(
      session: session(expiresAt: DateTime.now().add(const Duration(hours: 1))),
    );

    await launch(tester);
    app.updates.add(
      transfer(
        id: 'x',
        status: TransferStatus.failed,
        errorKind: TransferErrorKind.unauthorized,
      ),
    );
    await settle(tester);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(
      find.text('Your session has expired. Please log in again.'),
      findsOneWidget,
    );
    await finish(tester);
  });
}

/// Shorthand for the result type the files repository returns.
typedef RemoteFilesSnapshotResult = Result<RemoteFilesSnapshot, Failure>;
