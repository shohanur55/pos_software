import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../theme/app_theme.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../../widgets/common/snackbars.dart';
import '../../widgets/typography/app_text.dart';
import 'widgets/login_form.dart';
import 'widgets/register_portal_link.dart';

/// Login screen: branded header, a card with the form, and the sign-up prompt.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key, required this.serverAddress});

  final String serverAddress;

  void _showNotice(BuildContext context, AuthState state) {
    final notice = state.notice!;
    switch (notice.kind) {
      case AuthNoticeKind.loginFailed:
        context.showAppSnackBar(
          UiMessages.failureMessage(notice.failure),
          tone: SnackBarTone.error,
        );
      case AuthNoticeKind.portalOpenFailed:
        // The portal opens in-app now, so this branch runs only if something
        // dispatches the legacy event; still show a tone-matched message.
        context.showAppSnackBar(
          AppStrings.errorCannotOpenPortal(serverAddress),
          tone: SnackBarTone.error,
        );
      // The root listener shows this one, so it survives the jump to login.
      case AuthNoticeKind.sessionExpired:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          previous.notice != current.notice && current.notice != null,
      listener: (context, state) => _showNotice(context, state),
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 720;
            return Stack(
              children: [
                const _BrandBackdrop(),
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: context.spacing.lg,
                      vertical: context.spacing.lg,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 460 : context.sizes.formMaxWidth,
                        ),
                        child: _LoginContent(serverAddress: serverAddress),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Soft brand wash behind the card: a green gradient at the top fading into
/// the surface.
class _BrandBackdrop extends StatelessWidget {
  const _BrandBackdrop();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandPrimary.withValues(alpha: isDark ? 0.22 : 0.16),
              AppTheme.brandPrimary.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45],
          ),
        ),
      ),
    );
  }
}

class _LoginContent extends StatelessWidget {
  const _LoginContent({required this.serverAddress});

  final String serverAddress;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: context.spacing.xxl),
        Center(child: _BrandBadge()),
        SizedBox(height: context.spacing.xl),
        HeadingLargeText(
          AppStrings.loginTitle,
          textAlign: TextAlign.center,
          color: colors.textPrimary,
        ),
        SizedBox(height: context.spacing.xs),
        BodyMediumText(
          AppStrings.loginSubtitle,
          textAlign: TextAlign.center,
          color: colors.textSecondary,
        ),
        SizedBox(height: context.spacing.xl),
        _LoginCard(),
        SizedBox(height: context.spacing.lg),
        const RegisterPortalLink(),
        SizedBox(height: context.spacing.lg),
      ],
    );
  }
}

/// Small branded mark above the greeting.
class _BrandBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.brandPrimary, AppTheme.brandPrimaryDark],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandPrimary.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(
        Icons.point_of_sale_rounded,
        size: 36,
        color: Colors.white,
      ),
    );
  }
}

/// White card that frames the form, lifted off the gradient with a soft shadow.
class _LoginCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: EdgeInsets.all(context.spacing.xl),
      child: const LoginForm(),
    );
  }
}
