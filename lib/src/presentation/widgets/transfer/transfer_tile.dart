import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/file_name_utils.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_status.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../typography/app_text.dart';
import 'transfer_action.dart';
import 'transfer_action_buttons.dart';
import 'transfer_limit_note.dart';
import 'transfer_progress_bar.dart';
import 'transfer_stats_row.dart';
import 'transfer_status_chip.dart';

/// One row of the Transfers list. Stateless and callback-driven so it can be
/// rendered in isolation (and in tests) without a bloc.
class TransferTile extends StatelessWidget {
  const TransferTile({
    super.key,
    required this.transfer,
    required this.onAction,
    this.highlighted = false,
    this.serverCannotResumeUploads = false,
    this.now,
  });

  final TransferEntity transfer;
  final ValueChanged<TransferAction> onAction;
  final bool highlighted;

  /// The server has been asked and cannot continue an interrupted upload.
  final bool serverCannotResumeUploads;

  /// Reference time for the relative timestamp; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final showProgress =
        transfer.status != TransferStatus.completed &&
        transfer.status != TransferStatus.canceled;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: highlighted ? colors.highlight : colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: highlighted
              ? colors.primary
              : colors.outline.withValues(alpha: 0.55),
          width: highlighted ? 1.6 : context.sizes.borderWidth,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.18),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      padding: context.padding.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(transfer: transfer),
          if (showProgress) ...[
            SizedBox(height: context.spacing.md),
            Row(
              children: [
                Expanded(child: TransferProgressBar(transfer: transfer)),
                SizedBox(width: context.spacing.md),
                LabelText(
                  UiMessages.percent(transfer.progress),
                  color: colors.textPrimary,
                  maxLines: 1,
                ),
              ],
            ),
          ],
          SizedBox(height: context.spacing.md),
          TransferStatsRow(transfer: transfer),
          if (transfer.status == TransferStatus.failed) ...[
            SizedBox(height: context.spacing.sm),
            BodySmallText(
              UiMessages.transferErrorMessage(transfer.errorKind),
              color: colors.error,
            ),
          ],
          if (transfer.status == TransferStatus.waitingToRetry) ...[
            SizedBox(height: context.spacing.sm),
            BodySmallText(
              AppStrings.statusWaitingDetail,
              color: colors.warning,
            ),
          ],
          TransferLimitNote(
            transfer: transfer,
            serverCannotResumeUploads: serverCannotResumeUploads,
          ),
          if (transfer.status == TransferStatus.completed &&
              transfer.savedPath != null) ...[
            SizedBox(height: context.spacing.sm),
            BodySmallText(
              AppStrings.savedTo(
                FileNameUtils.shortLocation(transfer.savedPath!),
              ),
              maxLines: 2,
            ),
          ],
          Row(
            children: [
              Expanded(
                child: BodySmallText(
                  UiMessages.relativeTime(
                    transfer.updatedAt,
                    now ?? DateTime.now(),
                  ),
                  maxLines: 1,
                ),
              ),
              TransferActionButtons(transfer: transfer, onAction: onAction),
            ],
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.transfer});

  final TransferEntity transfer;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: context.sizes.avatar,
          height: context.sizes.avatar,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: context.radius.md,
          ),
          child: Icon(
            transfer.isUpload ? Icons.upload_rounded : Icons.download_rounded,
            color: colors.onPrimaryContainer,
            semanticLabel: transfer.isUpload
                ? AppStrings.tabUpload
                : AppStrings.download,
          ),
        ),
        SizedBox(width: context.spacing.md),
        // The chip sits under the name so long labels and large text never
        // squeeze the file name on narrow screens.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TitleText(transfer.fileName, maxLines: 2),
              SizedBox(height: context.spacing.xs),
              TransferStatusChip(transfer: transfer),
            ],
          ),
        ),
      ],
    );
  }
}
