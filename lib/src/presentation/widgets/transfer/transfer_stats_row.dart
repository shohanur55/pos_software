import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_status.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../typography/app_text.dart';

/// Transferred / speed / remaining, read at a glance like a till display.
class TransferStatsRow extends StatelessWidget {
  const TransferStatsRow({super.key, required this.transfer});

  final TransferEntity transfer;

  @override
  Widget build(BuildContext context) {
    final total = transfer.totalBytes;
    final running = transfer.status == TransferStatus.running;
    final speed = transfer.speedBytesPerSecond;
    final remaining = transfer.timeRemaining;

    final transferred = total == null || total <= 0
        ? ByteFormatter.format(transfer.transferredBytes)
        : '${ByteFormatter.format(transfer.transferredBytes)} / ${ByteFormatter.format(total)}';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Stat(label: AppStrings.statTransferred, value: transferred),
        _Stat(
          label: AppStrings.statSpeed,
          value: running && speed != null && speed > 0
              ? ByteFormatter.formatSpeed(speed)
              : AppStrings.valueUnknown,
        ),
        _Stat(
          label: AppStrings.statRemaining,
          value: running && remaining != null && remaining > Duration.zero
              ? UiMessages.timeLeft(remaining)
              : AppStrings.valueUnknown,
          last: true,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.last = false});

  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: last
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          LabelSmallText(
            label,
            color: context.color.textSecondary,
            maxLines: 1,
          ),
          SizedBox(height: context.spacing.xxs),
          BodySmallText(
            value,
            color: context.color.textPrimary,
            maxLines: 1,
            textAlign: last ? TextAlign.end : TextAlign.start,
          ),
        ],
      ),
    );
  }
}
