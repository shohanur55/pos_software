import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../typography/app_text.dart';

/// The line under a transfer explaining what will happen to it: what a paused
/// transfer does on resume, or (for an upload on a server that can't resume)
/// that pausing costs the whole file. The second case shows while the upload
/// is still running, so the user learns it before pausing rather than after.
class TransferLimitNote extends StatelessWidget {
  const TransferLimitNote({
    super.key,
    required this.transfer,
    this.serverCannotResumeUploads = false,
  });

  final TransferEntity transfer;

  // Only true once the server has been asked and said no.
  final bool serverCannotResumeUploads;

  // The text for [transfer], or null when there's nothing to say.
  static String? messageFor(
    TransferEntity transfer, {
    required bool serverCannotResumeUploads,
  }) {
    if (serverCannotResumeUploads &&
        transfer.isUpload &&
        !transfer.status.isFinished) {
      return AppStrings.uploadNoResumeNote;
    }
    return UiMessages.pausedDetail(transfer);
  }

  @override
  Widget build(BuildContext context) {
    final message = messageFor(
      transfer,
      serverCannotResumeUploads: serverCannotResumeUploads,
    );
    if (message == null) return const SizedBox.shrink();
    final colors = context.color;
    final reassuring = transfer.resumesWhereItStopped;
    final tone = reassuring ? colors.textSecondary : colors.warning;
    return Padding(
      padding: EdgeInsets.only(top: context.spacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            reassuring
                ? Icons.info_outline_rounded
                : Icons.warning_amber_rounded,
            size: context.sizes.iconSm,
            color: tone,
          ),
          SizedBox(width: context.spacing.sm),
          Expanded(child: BodySmallText(message, color: tone, maxLines: 4)),
        ],
      ),
    );
  }
}
