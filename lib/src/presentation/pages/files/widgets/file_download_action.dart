import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../domain/entities/remote_file_entity.dart';
import '../../../../domain/entities/transfer_entity.dart';
import '../../../../domain/entities/transfer_status.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/common/notification_permission_prompt.dart';
import '../../../widgets/transfer/transfer_progress_bar.dart';
import '../../../widgets/typography/app_text.dart';

/// Trailing action of a file row, driven by the file's latest download.
class FileDownloadAction extends StatelessWidget {
  const FileDownloadAction({
    super.key,
    required this.file,
    required this.download,
  });

  final RemoteFileEntity file;
  final TransferEntity? download;

  Future<void> _startDownload(BuildContext context) async {
    final bloc = context.read<TransferBloc>();
    unawaited(HapticFeedback.mediumImpact());
    await ensureNotificationPermission(context);
    bloc.add(DownloadStarted(file));
  }

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    final current = download;
    final (icon, tooltip, onPressed) = switch (current?.status) {
      null || TransferStatus.canceled => (
        Icons.download_rounded,
        AppStrings.download,
        () => _startDownload(context),
      ),
      TransferStatus.paused => (
        Icons.play_arrow_rounded,
        AppStrings.resume,
        () => bloc.add(TransferResumed(current!.id)),
      ),
      TransferStatus.queued ||
      TransferStatus.running ||
      TransferStatus.waitingToRetry => (
        Icons.pause_rounded,
        AppStrings.pause,
        () => bloc.add(TransferPaused(current!.id)),
      ),
      TransferStatus.completed => (
        Icons.open_in_new_rounded,
        AppStrings.open,
        () => bloc.add(TransferOpened(current!.id)),
      ),
      TransferStatus.failed => (
        Icons.refresh_rounded,
        AppStrings.retry,
        () => bloc.add(TransferRetried(current!.id)),
      ),
    };
    return IconButton.filledTonal(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}

class InlineDownloadProgress extends StatelessWidget {
  const InlineDownloadProgress({super.key, required this.transfer});

  final TransferEntity transfer;

  @override
  Widget build(BuildContext context) {
    // Stacked so a long status label cannot overflow a narrow row.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TransferProgressBar(transfer: transfer, thin: true),
        SizedBox(height: context.spacing.xs),
        LabelSmallText(
          transfer.status == TransferStatus.running
              ? UiMessages.percent(transfer.progress)
              : UiMessages.statusLabel(transfer),
          color: context.color.textSecondary,
          maxLines: 1,
        ),
      ],
    );
  }
}
