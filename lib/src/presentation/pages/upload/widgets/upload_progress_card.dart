import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../domain/entities/transfer_entity.dart';
import '../../../../domain/entities/transfer_status.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/common/file_type_icon.dart';
import '../../../widgets/transfer/confirm_pause.dart';
import '../../../widgets/transfer/transfer_action.dart';
import '../../../widgets/transfer/transfer_action_buttons.dart';
import '../../../widgets/transfer/transfer_limit_note.dart';
import '../../../widgets/transfer/transfer_progress_bar.dart';
import '../../../widgets/transfer/transfer_stats_row.dart';
import '../../../widgets/transfer/transfer_status_chip.dart';
import '../../../widgets/typography/app_text.dart';

/// The upload in flight, with the numbers an operator checks while waiting.
class UploadProgressCard extends StatelessWidget {
  const UploadProgressCard({super.key, required this.transfer});

  final TransferEntity transfer;

  Future<void> _onAction(
    BuildContext context,
    TransferAction action,
    bool uploadsRestart,
  ) async {
    HapticFeedback.selectionClick().ignore();
    final bloc = context.read<TransferBloc>();
    switch (action) {
      case TransferAction.pause:
        final go = await confirmPause(
          context,
          transfer: transfer,
          serverCannotResumeUploads: uploadsRestart,
        );
        if (go) bloc.add(TransferPaused(transfer.id));
      case TransferAction.resume:
        bloc.add(TransferResumed(transfer.id));
      case TransferAction.cancel:
        bloc.add(TransferCanceled(transfer.id));
      case TransferAction.retry:
        bloc.add(TransferRetried(transfer.id));
      case TransferAction.open || TransferAction.remove:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary,
                  colors.primary.withValues(alpha: 0.35),
                ],
              ),
            ),
          ),
          Padding(
            padding: context.padding.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FileTypeIcon(fileName: transfer.fileName),
                    SizedBox(width: context.spacing.md),
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
                ),
                SizedBox(height: context.spacing.lg),
                _PercentRow(transfer: transfer),
                SizedBox(height: context.spacing.sm),
                TransferProgressBar(transfer: transfer),
                SizedBox(height: context.spacing.lg),
                TransferStatsRow(transfer: transfer),
                if (transfer.status == TransferStatus.waitingToRetry) ...[
                  SizedBox(height: context.spacing.md),
                  BodySmallText(
                    AppStrings.statusWaitingDetail,
                    color: colors.warning,
                  ),
                ],
                BlocSelector<TransferBloc, TransferState, bool>(
                  selector: (state) => state.uploadsRestartFromStart,
                  builder: (context, uploadsRestart) => TransferLimitNote(
                    transfer: transfer,
                    serverCannotResumeUploads: uploadsRestart,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TransferActionButtons(
                    transfer: transfer,
                    exclude: const {TransferAction.open, TransferAction.remove},
                    onAction: (action) => _onAction(
                      context,
                      action,
                      context
                          .read<TransferBloc>()
                          .state
                          .uploadsRestartFromStart,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PercentRow extends StatelessWidget {
  const _PercentRow({required this.transfer});

  final TransferEntity transfer;

  @override
  Widget build(BuildContext context) {
    // Counts up with the bar instead of snapping between values.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: transfer.progress),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, value, child) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          DisplayText(
            UiMessages.percent(value),
            semanticsLabel: UiMessages.percent(transfer.progress),
          ),
        ],
      ),
    );
  }
}
