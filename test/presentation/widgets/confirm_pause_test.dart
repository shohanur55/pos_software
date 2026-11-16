import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/domain/entities/transfer_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/presentation/theme/app_theme.dart';
import 'package:pos_software/src/presentation/widgets/transfer/confirm_pause.dart';

import '../../helpers/fixtures.dart';

void main() {
  /// Returns a holder because the answer only lands once the dialog, if any,
  /// has been dismissed.
  Future<List<bool?>> pauseWith(
    WidgetTester tester,
    TransferEntity item, {
    required bool serverCannotResumeUploads,
  }) async {
    final answer = <bool?>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async => answer.add(
                await confirmPause(
                  context,
                  transfer: item,
                  serverCannotResumeUploads: serverCannotResumeUploads,
                ),
              ),
              child: const Text('pause'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('pause'));
    await tester.pumpAndSettle();
    return answer;
  }

  testWidgets('an upload that would start over asks first', (tester) async {
    await pauseWith(
      tester,
      transfer(status: TransferStatus.running, progress: 0.4),
      serverCannotResumeUploads: true,
    );

    expect(find.text('Pause this upload?'), findsOneWidget);
    expect(find.textContaining('will have to go again'), findsOneWidget);
    // The byte count makes the cost concrete rather than abstract.
    expect(find.textContaining('400 B'), findsOneWidget);
  });

  testWidgets('keeping the upload running refuses the pause', (tester) async {
    final answer = await pauseWith(
      tester,
      transfer(status: TransferStatus.running, progress: 0.4),
      serverCannotResumeUploads: true,
    );

    await tester.tap(find.text('Keep uploading'));
    await tester.pumpAndSettle();

    expect(find.text('Pause this upload?'), findsNothing);
    expect(answer, [false]);
  });

  testWidgets('pausing anyway goes ahead', (tester) async {
    final answer = await pauseWith(
      tester,
      transfer(status: TransferStatus.running, progress: 0.4),
      serverCannotResumeUploads: true,
    );

    await tester.tap(find.text('Pause anyway'));
    await tester.pumpAndSettle();

    expect(find.text('Pause this upload?'), findsNothing);
    expect(answer, [true]);
  });

  testWidgets('a download is never worth a confirmation', (tester) async {
    final answer = await pauseWith(
      tester,
      transfer(
        type: TransferType.download,
        status: TransferStatus.running,
        canPauseNatively: true,
      ),
      serverCannotResumeUploads: true,
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, [true]);
  });

  testWidgets('an upload with nothing sent yet is not worth a tap', (
    tester,
  ) async {
    final answer = await pauseWith(
      tester,
      transfer(status: TransferStatus.queued, progress: 0, totalBytes: null),
      serverCannotResumeUploads: true,
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, [true]);
  });

  testWidgets('no dialog until the server has actually said no', (
    tester,
  ) async {
    final answer = await pauseWith(
      tester,
      transfer(status: TransferStatus.running, progress: 0.4),
      serverCannotResumeUploads: false,
    );

    expect(find.byType(AlertDialog), findsNothing);
    expect(answer, [true]);
  });
}
