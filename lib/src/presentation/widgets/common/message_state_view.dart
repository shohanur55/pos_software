import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import '../typography/app_text.dart';

/// Centered icon + message + optional action, used for empty and error states.
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
    return Center(
      child: SingleChildScrollView(
        padding: context.padding.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: context.sizes.iconXl,
              color: isError ? colors.error : colors.textSecondary,
            ),
            SizedBox(height: context.spacing.lg),
            BodyLargeText(
              message,
              textAlign: TextAlign.center,
              color: colors.textSecondary,
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: context.spacing.lg),
              FilledButton.tonal(
                onPressed: onAction,
                child: LabelText(
                  actionLabel!,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
