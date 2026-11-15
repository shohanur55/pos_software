import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/core/di/dependency_injection.dart';
import 'package:pos_software/src/domain/entities/notification_permission_status.dart';
import 'package:pos_software/src/domain/entities/picked_file_entity.dart';
import 'package:pos_software/src/domain/entities/remote_file_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/domain/entities/upload_validation_error.dart';
import 'package:pos_software/src/presentation/app.dart';
import 'package:pos_software/src/presentation/blocs/upload/upload_bloc.dart';
import 'package:pos_software/src/presentation/pages/login/login_page.dart';
import 'package:pos_software/src/presentation/pages/shell/main_shell_page.dart';
import 'package:pos_software/src/presentation/router/router.dart';
import 'package:pos_software/src/presentation/router/routes.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Renders every screen at phone, tablet and landscape sizes with long
/// names, every transfer status and all banners visible. Any overflow or
/// layout exception fails the test.
void main() {
  const longName =
      'quarterly_inventory_export_all_branches_2026_final_reviewed_v12.csv';

  const devices = <String, Size>{
    'small phone 320x568': Size(320, 568),
    'phone 360x800': Size(360, 800),
    'large phone 430x932': Size(430, 932),
    'phone landscape 667x375': Size(667, 375),
    'large phone landscape 932x430': Size(932, 430),
    'tablet portrait 768x1024': Size(768, 1024),
    'tablet landscape 1280x800': Size(1280, 800),
    'foldable 280x653': Size(280, 653),
  };

  final allStatuses = <TransferEntity>[
    for (final (index, status) in TransferStatus.values.indexed)
      TransferEntity(
        id: 'transfer-$index',
        type: index.isEven ? TransferType.download : TransferType.upload,
        fileName: longName,
        remoteFileName: longName,
        status: status,
        progress: status == TransferStatus.completed ? 1 : 0.37,
        totalBytes: 480 * 1024 * 1024,
        transferredBytes: 177 * 1024 * 1024,
        speedBytesPerSecond: 2.4 * 1024 * 1024,
        timeRemaining: const Duration(minutes: 3),
        errorKind: status == TransferStatus.failed
            ? TransferErrorKind.network
            : null,
        savedPath: status == TransferStatus.completed
            ? '/storage/emulated/0/Download/POS Software/$longName'
            : null,
        createdAt: fixedNow.subtract(Duration(minutes: index * 7)),
        updatedAt: fixedNow.subtract(Duration(minutes: index * 7)),
      ),
  ];

  final remoteFiles = <RemoteFileEntity>[
    RemoteFileEntity(
      name: longName,
      url: 'http://server.test:90/get?file=x',
      sizeBytes: 480 * 1024 * 1024,
      uploadedAt: fixedNow,
    ),
    const RemoteFileEntity(
      name: 'a.png',
      url: 'http://server.test:90/get?file=a',
    ),
    for (var index = 0; index < 12; index++)
      RemoteFileEntity(
        name: 'video_$index.mp4',
        url: 'http://server.test:90/get?file=$index',
        sizeBytes: index * 1024,
      ),
  ];

  const invalidFile = PickedFileEntity(
    path: '/tmp/$longName',
    name: longName,
    sizeBytes: 700 * 1024 * 1024,
    extension: 'csv',
  );

  late TestApp app;

  setUp(() => app = TestApp());

  Future<void> pumpApp(WidgetTester tester, Size size, double textScale) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await app.start();
    await tester.pumpWidget(const PosApp());
    await settle(tester);
  }

  /// Unmounts the app and closes the blocs inside the test body, because the
  /// framework checks for pending timers before tear-down callbacks run.
  Future<void> finish(WidgetTester tester) async {
    // Let snackbars and the highlight timer run out.
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox.shrink());
    app.dispose();
    await tester.pump();
  }

  for (final MapEntry(key: device, value: size) in devices.entries) {
    for (final textScale in [1.0, 1.3]) {
      final label = '$device, text ${textScale}x';

      testWidgets('login fits: $label', (tester) async {
        await app.register();
        await pumpApp(tester, size, textScale);

        expect(find.byType(LoginPage), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Validation messages make the form taller.
        await tester.ensureVisible(find.text('Log in'));
        await tester.tap(find.text('Log in'));
        await settle(tester);
        expect(find.text('Enter your username'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await finish(tester);
      });

      testWidgets('signed-in screens fit: $label', (tester) async {
        app.uploadSeed = const UploadState(
          selectedFile: invalidFile,
          validationError: UploadValidationError.tooLarge,
        );
        await app.register(
          session: session(
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ),
          history: allStatuses,
          remoteFiles: remoteFiles,
          online: false,
          permission: NotificationPermissionStatus.denied,
        );
        await pumpApp(tester, size, textScale);

        expect(find.byType(MainShellPage), findsOneWidget);
        expect(
          find.byType(NavigationRail).evaluate().isNotEmpty,
          size.width >= 840,
          reason: 'rail on wide layouts, bottom bar otherwise',
        );
        expect(tester.takeException(), isNull, reason: 'Upload tab (form)');

        final router = sl<AppRouter>().router;
        router.go(Routes.files);
        await settle(tester);
        expect(find.text(longName), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Files tab');

        router.go(Routes.transfersFor('transfer-5', token: 1));
        await settle(tester);
        expect(find.text('Clear finished'), findsNothing);
        expect(find.byTooltip('Clear finished'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Transfers tab');

        // Scroll through every status so each tile variant is laid out.
        final list = find.byType(Scrollable).last;
        for (var i = 0; i < 12; i++) {
          await tester.drag(list, const Offset(0, -400));
          await settle(tester);
          expect(tester.takeException(), isNull, reason: 'Transfers scroll $i');
        }

        router.go(Routes.upload);
        await settle(tester);
        expect(tester.takeException(), isNull, reason: 'Upload tab again');
        await finish(tester);
      });

      testWidgets('upload progress card fits: $label', (tester) async {
        for (final status in [
          TransferStatus.waitingToRetry,
          TransferStatus.paused,
          TransferStatus.failed,
          TransferStatus.completed,
        ]) {
          app = TestApp()
            ..uploadSeed = const UploadState(
              selectedFile: invalidFile,
              submitStatus: SubmitStatus.started,
              activeTransferId: 'upload',
            );
          await app.register(
            session: session(
              expiresAt: DateTime.now().add(const Duration(hours: 1)),
            ),
            history: [
              transfer(
                id: 'upload',
                status: status,
                fileName: longName,
                errorKind: TransferErrorKind.server,
              ),
            ],
          );
          await pumpApp(tester, size, textScale);
          expect(tester.takeException(), isNull, reason: 'upload $status');
          await finish(tester);
        }
      });
    }
  }
}

/// Progress indicators animate forever, so `pumpAndSettle` would time out.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}
