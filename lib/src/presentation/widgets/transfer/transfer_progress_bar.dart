import 'package:flutter/material.dart';

import '../../../domain/entities/transfer_entity.dart';
import '../../../domain/entities/transfer_status.dart';
import '../../theme/theme_extensions.dart';

/// Determinate whenever the size is known; indeterminate only while running
/// without a total.
class TransferProgressBar extends StatelessWidget {
  const TransferProgressBar({
    super.key,
    required this.transfer,
    this.thin = false,
  });

  final TransferEntity transfer;
  final bool thin;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final unknownTotal =
        (transfer.totalBytes ?? 0) <= 0 && transfer.progress == 0;
    final indeterminate =
        transfer.status == TransferStatus.running && unknownTotal;
    final color = switch (transfer.status) {
      TransferStatus.completed => colors.success,
      TransferStatus.failed => colors.error,
      TransferStatus.paused || TransferStatus.waitingToRetry => colors.warning,
      _ => colors.primary,
    };
    return TweenAnimationBuilder<double>(
      // Progress arrives in steps; tweening keeps the bar from jumping.
      tween: Tween(begin: 0, end: transfer.progress),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      builder: (context, value, child) => LinearProgressIndicator(
        value: indeterminate ? null : value,
        minHeight: thin
            ? context.sizes.thinProgressBar
            : context.sizes.progressBar,
        color: color,
        backgroundColor: colors.surfaceContainer,
        borderRadius: context.radius.pill,
      ),
    );
  }
}
