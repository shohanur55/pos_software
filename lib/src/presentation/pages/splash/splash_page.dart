import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../theme/theme_extensions.dart';
import '../../widgets/typography/app_text.dart';

/// Shown while `AuthBloc` resolves the stored session; the router leaves
/// this page as soon as the status is known.
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.point_of_sale_rounded,
              size: context.sizes.iconXl,
              color: colors.primary,
            ),
            SizedBox(height: context.spacing.lg),
            const HeadingLargeText(AppStrings.appName),
            SizedBox(height: context.spacing.xl),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
