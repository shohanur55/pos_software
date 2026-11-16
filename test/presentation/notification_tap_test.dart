import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/core/di/dependency_injection.dart';
import 'package:pos_software/src/domain/entities/auth_session_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_notification_tap_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/presentation/app.dart';
import 'package:pos_software/src/presentation/router/app_navigation_service.dart';
import 'package:pos_software/src/presentation/router/router.dart';
import 'package:pos_software/src/presentation/router/routes.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_app.dart';

/// Covers the requirement that a completion notification, once tapped, puts
/// the operator on a screen that means something — from a running app and from
/// one that the tap itself started.
void main() {
  late TestApp app;

  setUp(() => app = TestApp());

  /// A session the app will accept: the bloc checks expiry against the real
  /// clock, so a fixed date would read as already expired.
  AuthSessionEntity liveSession() =>
      session(expiresAt: DateTime.now().add(const Duration(hours: 1)));

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

  /// Fills the login form and submits it, the way an operator would after a
  /// tap woke the app on the login screen.
  Future<void> signIn(WidgetTester tester) async {
    when(
      () => app.auth.login(
        username: any(named: 'username'),
        password: any(named: 'password'),
      ),
    ).thenAnswer((_) async => Success(liveSession()));
    await tester.enterText(find.byType(TextField).first, 'cashier');
    await tester.enterText(find.byType(TextField).last, 'secret');
    await tester.tap(find.text('Log in').last);
    await settle(tester);
  }

  String location() =>
      sl<AppRouter>().router.routerDelegate.currentConfiguration.uri.toString();

  final uploaded = transfer(
    id: 'up-1',
    type: TransferType.upload,
    status: TransferStatus.completed,
    progress: 1,
    fileName: 'catalog.csv',
  );
  final downloaded = transfer(
    id: 'down-1',
    type: TransferType.download,
    status: TransferStatus.completed,
    progress: 1,
    fileName: 'report.csv',
  );

  group('where a tap lands', () {
    test('a finished upload opens the file list it just changed', () {
      expect(
        AppNavigationService.destinationFor(
          const TransferNotificationTapEntity(
            transferId: 'up-1',
            type: TransferType.upload,
            isCompleted: true,
          ),
        ),
        Routes.files,
      );
    });

    test('a finished download opens its own row in Transfers', () {
      final location = AppNavigationService.destinationFor(
        const TransferNotificationTapEntity(
          transferId: 'down-1',
          type: TransferType.download,
          isCompleted: true,
        ),
        token: 3,
      );

      expect(location, startsWith(Routes.transfers));
      expect(Uri.parse(location).queryParameters, {
        Routes.highlightParam: 'down-1',
        Routes.highlightTokenParam: '3',
      });
    });

    test('an upload that did not finish opens its row, not the file list', () {
      // Tapping a failure notification and landing on Files would show no
      // sign of what went wrong.
      final location = AppNavigationService.destinationFor(
        const TransferNotificationTapEntity(
          transferId: 'up-1',
          type: TransferType.upload,
          isCompleted: false,
        ),
      );

      expect(location, startsWith(Routes.transfers));
    });
  });

  group('tapping while the app is running', () {
    testWidgets('a finished upload lands on the Files tab', (tester) async {
      await app.register(session: liveSession(), history: [uploaded]);
      await app.start();
      await tester.pumpWidget(const PosApp());
      await settle(tester);
      expect(location(), Routes.upload);

      app.notificationTaps.add(
        const TransferNotificationTapEntity(
          transferId: 'up-1',
          type: TransferType.upload,
          isCompleted: true,
        ),
      );
      await settle(tester);

      expect(location(), Routes.files);
      await finish(tester);
    });

    testWidgets('a finished download lands on its highlighted row', (
      tester,
    ) async {
      await app.register(session: liveSession(), history: [downloaded]);
      await app.start();
      await tester.pumpWidget(const PosApp());
      await settle(tester);

      app.notificationTaps.add(
        const TransferNotificationTapEntity(
          transferId: 'down-1',
          type: TransferType.download,
          isCompleted: true,
        ),
      );
      await settle(tester);

      final uri = Uri.parse(location());
      expect(uri.path, Routes.transfers);
      expect(uri.queryParameters[Routes.highlightParam], 'down-1');
      expect(find.text('report.csv'), findsOneWidget);
      await finish(tester);
    });

    testWidgets('tapping the same notification twice still moves', (
      tester,
    ) async {
      await app.register(session: liveSession(), history: [downloaded]);
      await app.start();
      await tester.pumpWidget(const PosApp());
      await settle(tester);

      const tap = TransferNotificationTapEntity(
        transferId: 'down-1',
        type: TransferType.download,
        isCompleted: true,
      );
      app.notificationTaps.add(tap);
      await settle(tester);
      final first = location();
      app.notificationTaps.add(tap);
      await settle(tester);

      // The request token changes, so the page is asked to scroll again
      // rather than treating the second tap as the same destination.
      expect(location(), isNot(first));
      expect(
        Uri.parse(location()).queryParameters[Routes.highlightParam],
        'down-1',
      );
      await finish(tester);
    });
  });

  group('tapping a notification that starts the app', () {
    testWidgets('the destination waits until the operator has signed in', (
      tester,
    ) async {
      // No session: the tap arrives before anyone can be sent anywhere.
      await app.register(history: [downloaded]);
      await app.start();
      await tester.pumpWidget(const PosApp());
      await settle(tester);
      expect(location(), Routes.login);

      app.notificationTaps.add(
        const TransferNotificationTapEntity(
          transferId: 'down-1',
          type: TransferType.download,
          isCompleted: true,
        ),
      );
      await settle(tester);

      // Still on login — a tap must never jump past authentication.
      expect(location(), Routes.login);

      await signIn(tester);

      final uri = Uri.parse(location());
      expect(uri.path, Routes.transfers);
      expect(uri.queryParameters[Routes.highlightParam], 'down-1');
      await finish(tester);
    });

    testWidgets('a held destination is used once and not again', (
      tester,
    ) async {
      await app.register(history: [downloaded]);
      await app.start();
      await tester.pumpWidget(const PosApp());
      await settle(tester);

      app.notificationTaps.add(
        const TransferNotificationTapEntity(
          transferId: 'down-1',
          type: TransferType.download,
          isCompleted: true,
        ),
      );
      await settle(tester);

      await signIn(tester);

      expect(sl<AppRouter>().pendingLocation, isNull);
      await finish(tester);
    });
  });
}
