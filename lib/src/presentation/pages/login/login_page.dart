import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../../widgets/common/snackbars.dart';
import '../../widgets/typography/app_text.dart';
import 'widgets/login_form.dart';
import 'widgets/register_portal_link.dart';

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
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: context.padding.page,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.sizes.formMaxWidth,
                ),
                child: _LoginContent(serverAddress: serverAddress),
              ),
            ),
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
        Icon(
          Icons.point_of_sale_rounded,
          size: context.sizes.iconXl,
          color: colors.primary,
        ),
        SizedBox(height: context.spacing.lg),
        const HeadingLargeText(
          AppStrings.loginTitle,
          textAlign: TextAlign.center,
        ),
        SizedBox(height: context.spacing.xs),
        BodyMediumText(
          AppStrings.loginSubtitle,
          textAlign: TextAlign.center,
          color: colors.textSecondary,
        ),
        SizedBox(height: context.spacing.xl),
        const LoginForm(),
        SizedBox(height: context.spacing.lg),
        RegisterPortalLink(address: serverAddress),
      ],
    );
  }
}
