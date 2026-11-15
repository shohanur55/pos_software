import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/upload/upload_bloc.dart';
import '../../../theme/app_theme.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/common/dashed_border.dart';
import '../../../widgets/typography/app_text.dart';

/// The drop zone that starts file selection. The whole surface is tappable,
/// not just the button — easier on a counter-top tablet. The dashed border
/// and the brand-green gradient badge make it read as the page's primary
/// affordance.
class PickFileCard extends StatelessWidget {
  const PickFileCard({super.key, required this.isPicking});

  final bool isPicking;

  void _pick(BuildContext context) {
    HapticFeedback.selectionClick();
    context.read<UploadBloc>().add(const FilePickRequested());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return CustomPaint(
      painter: DashedBorderPainter(
        color: isPicking
            ? colors.primary
            : colors.primary.withValues(alpha: 0.45),
        radius: context.radius.lg.topLeft,
      ),
      child: Material(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isPicking ? null : () => _pick(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.lg,
              vertical: context.spacing.xxl,
            ),
            child: Column(
              children: [
                _Badge(isPicking: isPicking),
                SizedBox(height: context.spacing.lg),
                TitleText(
                  isPicking
                      ? AppStrings.uploadPreparing
                      : AppStrings.uploadChooseFile,
                  textAlign: TextAlign.center,
                  fontWeight: FontWeight.w700,
                ),
                SizedBox(height: context.spacing.xs),
                BodySmallText(
                  AppStrings.uploadCaption,
                  textAlign: TextAlign.center,
                  color: colors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.isPicking});

  final bool isPicking;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPicking)
            const SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: AppTheme.brandPrimary,
              ),
            ),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.brandPrimary, AppTheme.brandPrimaryDark],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }
}
