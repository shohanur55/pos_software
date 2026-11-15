import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_pause_reason.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/presentation/theme/app_theme.dart';
import 'package:pos_software/src/presentation/widgets/transfer/transfer_action.dart';
import 'package:pos_software/src/presentation/widgets/transfer/transfer_tile.dart';

import '../../helpers/fixtures.dart';

void main() {
  const longName =
      'monthly_inventory_export_for_all_branches_2026_with_extra_columns.csv';

  final cases = <String, (TransferEntity, List<String>, List<TransferAction>)>{
    'running': (
      transfer(fileName: longName, progress: 0.42, type: TransferType.download),
      ['Downloading', '42%'],
      [TransferAction.pause, TransferAction.cancel],
    ),
    'paused upload that has to start over': (
      transfer(
        fileName: longName,
        status: TransferStatus.paused,
        progress: 0.3,
        pauseReason: TransferPauseReason.user,
      ),
      ['Paused', 'Starts again from the beginning when resumed.'],
      [TransferAction.resume, TransferAction.cancel],
    ),
    'download parked by a dropped connection': (
      transfer(
        fileName: longName,
        type: TransferType.download,
        status: TransferStatus.paused,
        progress: 0.3,
        totalBytes: 80 * 1000 * 1000,
        canPauseNatively: true,
        pauseReason: TransferPauseReason.noNetwork,
      ),
      [
        'Waiting for internet',
        'No internet. Continues from 22.9 MB as soon as the connection is '
            'back.',
      ],
      [TransferAction.resume, TransferAction.cancel],
    ),
    'failed': (
      transfer(
        fileName: longName,
        status: TransferStatus.failed,
        errorKind: TransferErrorKind.network,
      ),
      [
        'Failed',
        "Can't reach the server. Check your internet connection and try again.",
      ],
      [TransferAction.retry, TransferAction.remove],
    ),
    'completed download': (
      transfer(
        fileName: longName,
        status: TransferStatus.completed,
        progress: 1,
        type: TransferType.download,
      ),
      ['Completed'],
      [TransferAction.open, TransferAction.remove],
    ),
  };

  Future<List<TransferAction>> pump(
    WidgetTester tester,
    TransferEntity transfer,
    double textScale,
  ) async {
    final tapped = <TransferAction>[];
    tester.view
      ..physicalSize = const Size(320, 900)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 900),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: TransferTile(
                transfer: transfer,
                onAction: tapped.add,
                now: fixedNow,
              ),
            ),
          ),
        ),
      ),
    );
    return tapped;
  }

  for (final scale in [1.0, 1.3]) {
    for (final entry in cases.entries) {
      testWidgets('${entry.key} renders without overflow at ${scale}x text', (
        tester,
      ) async {
        final (item, texts, actions) = entry.value;
        final tapped = await pump(tester, item, scale);

        expect(tester.takeException(), isNull);
        for (final text in texts) {
          expect(find.text(text), findsOneWidget);
        }
        expect(
          find.textContaining('%').evaluate().length,
          item.status == TransferStatus.completed ? 0 : greaterThan(0),
        );

        for (final action in actions) {
          final button = find.byWidgetPredicate(
            (widget) => widget is IconButton && widget.tooltip != null,
          );
          expect(button, findsNWidgets(actions.length));
          await tester.tap(button.at(actions.indexOf(action)));
        }
        expect(tapped, actions);
      });
    }
  }

  testWidgets('dark theme renders the failed state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: TransferTile(
            transfer: transfer(
              status: TransferStatus.failed,
              errorKind: TransferErrorKind.server,
            ),
            onAction: (_) {},
            now: fixedNow,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.text('The server ran into a problem. Please try again in a moment.'),
      findsOneWidget,
    );
  });
}
