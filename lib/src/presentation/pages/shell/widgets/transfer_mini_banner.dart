import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/common/info_banner.dart';
import '../../../widgets/typography/app_text.dart';

class _BannerData extends Equatable {
  const _BannerData(this.activeCount, this.percent, this.unseenFailed);

  final int activeCount;
  final int percent;
  final int unseenFailed;

  @override
  List<Object?> get props => [activeCount, percent, unseenFailed];
}

/// Persistent summary of running transfers, visible on every tab but Transfers.
class TransferMiniBanner extends StatelessWidget {
  const TransferMiniBanner({super.key, required this.onOpenTransfers});

  final VoidCallback onOpenTransfers;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TransferBloc, TransferState, _BannerData>(
      selector: (state) => _BannerData(
        state.activeCount,
        (state.overallProgress * 100).round(),
        state.unseenFailedCount,
      ),
      builder: (context, data) {
        if (data.activeCount > 0) {
          return _ActiveBanner(
            label: AppStrings.miniBannerActive(data.activeCount, data.percent),
            progress: data.percent / 100,
            onTap: onOpenTransfers,
          );
        }
        if (data.unseenFailed > 0) {
          return InfoBanner(
            icon: Icons.error_outline_rounded,
            tone: InfoBannerTone.error,
            message: AppStrings.miniBannerFailed(data.unseenFailed),
            actionLabel: AppStrings.view,
            onAction: onOpenTransfers,
            dismissTooltip: AppStrings.dismiss,
            onDismiss: () => context.read<TransferBloc>().add(
              const TransferFailuresAcknowledged(),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

/// Brand-green gradient strip with a progress line on top and a one-line
/// summary underneath. Reads as "work is happening" without shouting.
class _ActiveBanner extends StatelessWidget {
  const _ActiveBanner({
    required this.label,
    required this.progress,
    required this.onTap,
  });

  final String label;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.brandPrimary,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: progress,
              minHeight: context.sizes.thinProgressBar,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
              borderRadius: BorderRadius.zero,
            ),
            Padding(
              padding: context.padding.banner,
              child: Row(
                children: [
                  const Icon(Icons.swap_vert_rounded, color: Colors.white),
                  SizedBox(width: context.spacing.md),
                  Expanded(
                    child: BodyMediumText(
                      label,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      maxLines: 2,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
