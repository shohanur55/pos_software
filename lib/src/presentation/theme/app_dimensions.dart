import 'package:flutter/widgets.dart';

@immutable
class AppSpacing {
  const AppSpacing();

  double get xxs => 2;
  double get xs => 4;
  double get sm => 8;
  double get md => 12;
  double get lg => 16;
  double get xl => 24;
  double get xxl => 32;
  double get xxxl => 48;
}

@immutable
class AppPadding {
  const AppPadding();

  static const AppSpacing _spacing = AppSpacing();

  EdgeInsets get page => EdgeInsets.all(_spacing.lg);
  EdgeInsets get card => EdgeInsets.all(_spacing.lg);
  EdgeInsets get tile =>
      EdgeInsets.symmetric(horizontal: _spacing.lg, vertical: _spacing.sm);
  EdgeInsets get banner =>
      EdgeInsets.symmetric(horizontal: _spacing.lg, vertical: _spacing.sm);
  EdgeInsets get chip =>
      EdgeInsets.symmetric(horizontal: _spacing.sm, vertical: _spacing.xxs);
  EdgeInsets get horizontal => EdgeInsets.symmetric(horizontal: _spacing.lg);

  /// Keeps a floating snack bar clear of the screen edges and the nav bar.
  EdgeInsets get snackBar =>
      EdgeInsets.fromLTRB(_spacing.md, _spacing.sm, _spacing.md, _spacing.md);

  /// Scrollable page content, with extra room below the last item.
  EdgeInsets get list =>
      EdgeInsets.fromLTRB(_spacing.lg, _spacing.sm, _spacing.lg, _spacing.xl);
}

@immutable
class AppRadius {
  const AppRadius();

  BorderRadius get sm => BorderRadius.circular(8);
  BorderRadius get md => BorderRadius.circular(12);
  BorderRadius get lg => BorderRadius.circular(16);
  BorderRadius get pill => BorderRadius.circular(999);
}

@immutable
class AppSizes {
  const AppSizes();

  double get iconSm => 16;
  double get iconMd => 24;
  double get iconLg => 32;
  double get iconXl => 56;
  double get avatar => 40;
  double get touchTarget => 48;
  double get progressBar => 6;
  double get thinProgressBar => 3;
  double get borderWidth => 1;
  double get formMaxWidth => 420;
  double get badgeOffset => 6;
}
