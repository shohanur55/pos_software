import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/domain/entities/picked_file_entity.dart';
import 'package:pos_software/src/domain/entities/transfer_error_kind.dart';
import 'package:pos_software/src/domain/entities/transfer_status.dart';
import 'package:pos_software/src/domain/entities/transfer_type.dart';
import 'package:pos_software/src/presentation/pages/upload/widgets/selected_file_tile.dart';
import 'package:pos_software/src/presentation/theme/app_theme.dart';
import 'package:pos_software/src/presentation/widgets/common/skeletons.dart';
import 'package:pos_software/src/presentation/widgets/transfer/transfer_tile.dart';

import '../helpers/fixtures.dart';
import '../helpers/golden_fonts.dart';

/// Renders the pieces that carry the look of the app, in both themes.
///
/// Run `flutter test --update-goldens` after a deliberate design change and
/// review the images in `test/golden/images/`.
void main() {
  setUpAll(loadGoldenFonts);

  Future<void> expectGolden(
    WidgetTester tester,
    String name,
    Widget child, {
    Size size = const Size(420, 760),
  }) async {
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final (label, theme) in [
      ('light', AppTheme.light),
      ('dark', AppTheme.dark),
    ]) {
      // Unmount first: tiles animate colour changes, so a shared element
      // would be captured mid cross-fade instead of in the new theme.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          // The test harness defaults to a placeholder font; name the real
          // one so the image shows readable text.
          theme: theme.copyWith(
            textTheme: theme.textTheme.apply(fontFamily: 'Roboto'),
          ),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('images/${name}_$label.png'),
      );
    }
  }

  testWidgets('transfer tiles', (tester) async {
    await expectGolden(
      tester,
      'transfer_tiles',
      Column(
        children: [
          TransferTile(
            transfer: transfer(
              id: 'a',
              type: TransferType.download,
              fileName: 'product_catalog_november.csv',
              progress: 0.42,
              totalBytes: 58 * 1024 * 1024,
              speedBytesPerSecond: 2.4 * 1024 * 1024,
              timeRemaining: const Duration(seconds: 35),
            ),
            onAction: (_) {},
            now: fixedNow,
          ),
          const SizedBox(height: 16),
          TransferTile(
            transfer: transfer(
              id: 'b',
              fileName: 'audit_report.csv',
              status: TransferStatus.failed,
              errorKind: TransferErrorKind.network,
            ),
            onAction: (_) {},
            now: fixedNow,
          ),
        ],
      ),
    );
  });

  testWidgets('completed download tile', (tester) async {
    await expectGolden(
      tester,
      'transfer_completed',
      TransferTile(
        transfer: transfer(
          id: 'c',
          type: TransferType.download,
          fileName: 'store_photos_batch_12.mp4',
          status: TransferStatus.completed,
          progress: 1,
          savedPath: '/storage/emulated/0/Download/POS Software/store_photos_batch_12.mp4',
        ),
        onAction: (_) {},
        now: fixedNow,
      ),
      size: const Size(420, 420),
    );
  });

  testWidgets('selected file tile', (tester) async {
    await expectGolden(
      tester,
      'selected_file',
      Column(
        children: [
          SelectedFileTile(
            file: const PickedFileEntity(
              path: '/tmp/catalog.csv',
              name: 'product_catalog_november.csv',
              sizeBytes: 2 * 1024 * 1024,
              extension: 'csv',
            ),
            onRemove: () {},
          ),
          const SizedBox(height: 16),
          SelectedFileTile(
            file: const PickedFileEntity(
              path: '/tmp/clip.mov',
              name: 'counter_clip.mov',
              sizeBytes: 700 * 1024 * 1024,
              extension: 'mov',
            ),
            error: 'This file is larger than the 512 MB limit.',
            onRemove: () {},
          ),
        ],
      ),
      size: const Size(420, 360),
    );
  });

  testWidgets('loading skeletons', (tester) async {
    await expectGolden(
      tester,
      'skeletons',
      const Column(
        children: [
          SizedBox(height: 240, child: FileListSkeleton(itemCount: 3)),
          SizedBox(height: 260, child: TransferListSkeleton(itemCount: 1)),
        ],
      ),
    );
  });
}
