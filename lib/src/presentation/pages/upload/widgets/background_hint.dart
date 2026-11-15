import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/typography/app_text.dart';

class BackgroundHint extends StatelessWidget {
  const BackgroundHint({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: context.sizes.iconSm,
          color: colors.textSecondary,
        ),
        SizedBox(width: context.spacing.sm),
        const Expanded(child: BodySmallText(AppStrings.uploadBackgroundHint)),
      ],
    );
  }
}
