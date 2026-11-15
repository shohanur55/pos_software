import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/presentation/theme/app_theme.dart';
import 'package:pos_software/src/presentation/widgets/common/snackbars.dart';

/// WCAG AA contrast for body text. A snack bar that inherits the page text
/// colour instead of its own looks fine in code and is unreadable on screen,
/// so the ratio is asserted rather than eyeballed.
double _contrast(Color a, Color b) {
  final first = a.computeLuminance();
  final second = b.computeLuminance();
  final lighter = math.max(first, second);
  final darker = math.min(first, second);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  Future<void> show(
    WidgetTester tester,
    ThemeData theme,
    SnackBarTone tone, {
    bool withAction = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.showAppSnackBar(
                'catalog_november.csv was saved.',
                tone: tone,
                actionLabel: withAction ? 'View' : null,
                onAction: withAction ? () {} : null,
              ),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('show'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Color backgroundOf(WidgetTester tester) {
    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    return bar.backgroundColor!;
  }

  Color messageColorOf(WidgetTester tester) {
    final text = tester.widget<Text>(
      find.text('catalog_november.csv was saved.'),
    );
    return text.style!.color!;
  }

  for (final (themeName, theme) in [
    ('light', AppTheme.light),
    ('dark', AppTheme.dark),
  ]) {
    for (final tone in SnackBarTone.values) {
      testWidgets('$themeName ${tone.name} message is readable', (
        tester,
      ) async {
        await show(tester, theme, tone);

        expect(
          _contrast(messageColorOf(tester), backgroundOf(tester)),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('$themeName ${tone.name} action is readable', (tester) async {
        await show(tester, theme, tone, withAction: true);

        final action = tester.widget<SnackBarAction>(
          find.byType(SnackBarAction),
        );
        expect(
          _contrast(action.textColor!, backgroundOf(tester)),
          greaterThanOrEqualTo(3),
        );
      });
    }
  }

  testWidgets(
    'one snack bar at a time, so the newest message is the visible one',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  context.showAppSnackBar('first');
                  context.showAppSnackBar('second');
                },
                child: const Text('show'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('show'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    },
  );
}
