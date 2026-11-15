import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../theme/theme_extensions.dart';
import '../typography/app_text.dart';

Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: HeadingMediumText(title),
      content: BodyMediumText(
        message,
        color: dialogContext.color.textSecondary,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: LabelText(
            cancelLabel ?? AppStrings.cancel,
            color: dialogContext.color.primary,
          ),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: dialogContext.color.error,
                  foregroundColor: dialogContext.color.onError,
                )
              : null,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: LabelText(
            confirmLabel,
            color: destructive
                ? dialogContext.color.onError
                : dialogContext.color.onPrimary,
          ),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
