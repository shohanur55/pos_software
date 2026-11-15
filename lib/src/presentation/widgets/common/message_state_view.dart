import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import '../typography/app_text.dart';

/// Centered illustration + message + optional action, used for empty and
/// error states. The icon sits in a soft tinted disc so an otherwise bare
/// screen still looks finished.
class MessageStateView extends StatelessWidget {
  const MessageStateView({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final accent = isError ? colors.error : colors.primary;
    final discBg = isError ? colors.errorContainer : colors.primaryContainer;
    return Center(
      child: SingleChildScrollView(
        padding: context.padding.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(shape: BoxShape.circle, color: discBg),
              child: Icon(icon, size: 44, color: accent),
            ),
            SizedBox(height: context.spacing.xl),
            BodyLargeText(
              message,
              textAlign: TextAlign.center,
              color: colors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: context.spacing.xl),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(
                  isError ? Icons.refresh_rounded : Icons.add_rounded,
                  color: colors.onPrimary,
                ),
                label: LabelText(actionLabel!, color: colors.onPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
