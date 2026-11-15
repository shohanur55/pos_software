import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/upload/upload_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/common/dashed_border.dart';
import '../../../widgets/typography/app_text.dart';

/// The drop zone that starts file selection. The whole area is tappable, not
/// just the button, which matters on a counter-top tablet.
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
        color: isPicking ? colors.primary : colors.outline,
        radius: context.radius.lg.topLeft,
      ),
      child: Material(
        color: colors.primaryContainer.withValues(alpha: 0.35),
        borderRadius: context.radius.lg,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isPicking ? null : () => _pick(context),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.spacing.lg,
              vertical: context.spacing.xl,
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
                ),
                SizedBox(height: context.spacing.xs),
                const BodySmallText(
                  AppStrings.uploadCaption,
                  textAlign: TextAlign.center,
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
    final colors = context.color;
    final size = context.sizes.iconXl;
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isPicking)
            SizedBox.square(
              dimension: size,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          Container(
            width: size - 14,
            height: size - 14,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              color: colors.onPrimaryContainer,
              size: context.sizes.iconMd,
            ),
          ),
        ],
      ),
    );
  }
}
