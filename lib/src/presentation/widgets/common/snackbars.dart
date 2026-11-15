import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import '../typography/app_text.dart';

/// How loud a transient message is. The tone picks the colours, the icon and
/// how long the message stays on screen.
enum SnackBarTone { info, success, warning, error }

extension SnackBars on BuildContext {
  void showAppSnackBar(
    String message, {
    SnackBarTone tone = SnackBarTone.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(this);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        buildAppSnackBar(
          this,
          message,
          tone: tone,
          actionLabel: actionLabel,
          onAction: onAction,
        ),
      );
  }
}

SnackBar buildAppSnackBar(
  BuildContext context,
  String message, {
  SnackBarTone tone = SnackBarTone.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final palette = _SnackPalette.of(context, tone);
  final hasAction = actionLabel != null && onAction != null;
  return SnackBar(
    content: _SnackContent(palette: palette, message: message),
    backgroundColor: palette.background,
    elevation: 6,
    behavior: SnackBarBehavior.floating,
    margin: context.padding.snackBar,
    padding: hasAction
        ? const EdgeInsets.fromLTRB(14, 10, 8, 10)
        : const EdgeInsets.fromLTRB(14, 14, 14, 14),
    shape: RoundedRectangleBorder(
      borderRadius: context.radius.lg,
      side: BorderSide(color: palette.border),
    ),
    duration: palette.duration,
    // A long file name must push the action onto its own line rather than
    // squeeze it, which is what the Material default does at 25%.
    actionOverflowThreshold: 0.5,
    action: hasAction
        ? SnackBarAction(
            label: actionLabel,
            onPressed: onAction,
            textColor: palette.accent,
            backgroundColor: palette.accent.withValues(alpha: 0.12),
          )
        : null,
  );
}

class _SnackContent extends StatelessWidget {
  const _SnackContent({required this.palette, required this.message});

  final _SnackPalette palette;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(palette.icon, size: context.sizes.iconMd, color: palette.accent),
        SizedBox(width: context.spacing.sm),
        Expanded(
          child: BodyMediumText(
            message,
            color: palette.foreground,
            maxLines: 3,
          ),
        ),
      ],
    );
  }
}

/// Colours, icon and dwell time for one [SnackBarTone].
class _SnackPalette {
  const _SnackPalette({
    required this.background,
    required this.foreground,
    required this.accent,
    required this.icon,
    required this.duration,
  });

  factory _SnackPalette.of(BuildContext context, SnackBarTone tone) {
    final colors = context.color;
    return switch (tone) {
      SnackBarTone.info => _SnackPalette(
        background: colors.primaryContainer,
        foreground: colors.onPrimaryContainer,
        accent: colors.primary,
        icon: Icons.info_outline_rounded,
        duration: const Duration(seconds: 4),
      ),
      SnackBarTone.success => _SnackPalette(
        background: colors.successContainer,
        foreground: colors.onSuccessContainer,
        accent: colors.success,
        icon: Icons.check_circle_outline_rounded,
        duration: const Duration(seconds: 4),
      ),
      SnackBarTone.warning => _SnackPalette(
        background: colors.warningContainer,
        foreground: colors.onWarningContainer,
        accent: colors.warning,
        icon: Icons.warning_amber_rounded,
        duration: const Duration(seconds: 5),
      ),
      SnackBarTone.error => _SnackPalette(
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
        accent: colors.error,
        icon: Icons.error_outline_rounded,
        duration: const Duration(seconds: 6),
      ),
    };
  }

  final Color background;
  final Color foreground;
  final Color accent;
  final IconData icon;
  final Duration duration;

  Color get border => accent.withValues(alpha: 0.32);
}
