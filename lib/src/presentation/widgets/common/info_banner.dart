import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import '../typography/app_text.dart';

enum InfoBannerTone { neutral, warning, error }

/// Slim, non-blocking banner used by the shell.
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.message,
    this.tone = InfoBannerTone.neutral,
    this.actionLabel,
    this.onAction,
    this.onDismiss,
    this.dismissTooltip,
  });

  final IconData icon;
  final String message;
  final InfoBannerTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onDismiss;
  final String? dismissTooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final (background, foreground) = switch (tone) {
      InfoBannerTone.neutral => (colors.surfaceContainer, colors.textPrimary),
      InfoBannerTone.warning => (
        colors.warningContainer,
        colors.onWarningContainer,
      ),
      InfoBannerTone.error => (colors.errorContainer, colors.onErrorContainer),
    };
    return Material(
      color: background,
      child: Padding(
        padding: context.padding.banner,
        child: Row(
          children: [
            Icon(icon, color: foreground, size: context.sizes.iconMd),
            SizedBox(width: context.spacing.md),
            // The action sits under the message: next to it, the text would
            // be squeezed to nothing on narrow screens with large fonts.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  BodySmallText(message, color: foreground),
                  if (actionLabel != null && onAction != null)
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        alignment: AlignmentDirectional.centerStart,
                      ),
                      onPressed: onAction,
                      child: LabelText(
                        actionLabel!,
                        color: foreground,
                        maxLines: 1,
                      ),
                    ),
                ],
              ),
            ),
            if (onDismiss != null)
              IconButton(
                tooltip: dismissTooltip,
                icon: Icon(Icons.close_rounded, color: foreground),
                onPressed: onDismiss,
              ),
          ],
        ),
      ),
    );
  }
}
