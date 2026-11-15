import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_extensions.dart';
import '../../widgets/typography/app_text.dart';

/// First frame the user sees. Stays up while `AuthBloc` resolves the stored
/// session; the router leaves this page as soon as the status is known.
///
/// The composition is a single on-brand surface: a soft radial glow, the mark
/// in a rounded tile that scales in, the product name, a muted tagline, and a
/// slim progress bar at the bottom. No long animation, no bounce — the point
/// is to look polished during the few hundred milliseconds the splash is on
/// screen, not to be a loading screen in its own right.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _logoScale = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
    );
    _fade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          fit: StackFit.expand,
          children: [
            // Brand glow in the upper third: a subtle radial wash of the
            // primary green that fades into the surface. Keeps the page from
            // looking empty without competing with the mark.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.5),
                  radius: 1.1,
                  colors: [
                    AppTheme.brandPrimary.withValues(
                      alpha: isDark ? 0.18 : 0.12,
                    ),
                    colors.background,
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  Transform.scale(
                    scale: 0.8 + 0.2 * _logoScale.value,
                    child: Opacity(
                      opacity: _logoScale.value,
                      child: _BrandMark(),
                    ),
                  ),
                  SizedBox(height: context.spacing.xl),
                  Opacity(
                    opacity: _fade.value,
                    child: Column(
                      children: [
                        DisplayText(
                          AppStrings.appName,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        SizedBox(height: context.spacing.sm),
                        BodyMediumText(
                          AppStrings.splashTagline,
                          color: colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                  Opacity(
                    opacity: _fade.value,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.spacing.xxxl,
                      ),
                      child: ClipRRect(
                        borderRadius: context.radius.pill,
                        child: LinearProgressIndicator(
                          minHeight: 4,
                          backgroundColor: colors.surfaceContainer,
                          valueColor: AlwaysStoppedAnimation(colors.primary),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.spacing.xl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The brand mark: a rounded green tile with the POS icon and a subtle
/// highlight. Matches what the launcher icon should eventually look like.
class _BrandMark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandPrimary, AppTheme.brandPrimaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Glossy top highlight.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Icon(
              Icons.point_of_sale_rounded,
              size: 56,
              color: colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
