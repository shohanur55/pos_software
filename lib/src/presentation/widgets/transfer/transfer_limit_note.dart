import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../typography/app_text.dart';

/// The one line under a transfer that explains what is about to happen to it:
/// what a paused transfer will do when it resumes, or — for an upload on a
/// server that cannot continue an interrupted one — that pausing costs the
/// whole file.
///
/// The second case is deliberately shown while the upload is still *running*.
/// Learning it from a snackbar after already pausing a 300 MB file is too
/// late to be any use.
class TransferLimitNote extends StatelessWidget {
  const TransferLimitNote({
    super.key,
    required this.transfer,
    this.serverCannotResumeUploads = false,
  });

  final TransferEntity transfer;

  /// Only ever true once the server has actually been asked and said no.
  final bool serverCannotResumeUploads;

  /// The text for [transfer], or `null` when there is nothing worth saying.
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
