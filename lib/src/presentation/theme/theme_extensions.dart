import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';

extension ThemeTokens on BuildContext {
  AppColors get color => Theme.of(this).extension<AppColors>()!;

  AppSpacing get spacing => const AppSpacing();

  AppPadding get padding => const AppPadding();

  AppRadius get radius => const AppRadius();

  AppSizes get sizes => const AppSizes();

  TextTheme get textTheme => Theme.of(this).textTheme;
}
