import 'package:flutter/material.dart';

import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_status.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../typography/app_text.dart';

class TransferStatusChip extends StatelessWidget {
  const TransferStatusChip({super.key, required this.transfer});

  final TransferEntity transfer;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final (background, foreground) = switch (transfer.status) {
      TransferStatus.completed => (
        colors.successContainer,
        colors.onSuccessContainer,
      ),
      TransferStatus.failed => (colors.errorContainer, colors.onErrorContainer),
      TransferStatus.paused || TransferStatus.waitingToRetry => (
        colors.warningContainer,
        colors.onWarningContainer,
      ),
      TransferStatus.canceled => (
        colors.surfaceContainer,
        colors.textSecondary,
      ),
      TransferStatus.queued || TransferStatus.running => (
        colors.primaryContainer,
        colors.onPrimaryContainer,
      ),
    };
    return Container(
      padding: context.padding.chip,
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.radius.pill,
      ),
      child: LabelSmallText(
        UiMessages.statusLabel(transfer),
        color: foreground,
        maxLines: 1,
      ),
    );
  }
}
