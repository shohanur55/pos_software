import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/typography/app_text.dart';

/// The server address as a link. Accounts are created on the web portal, so
/// the address has to be reachable from here, not just readable.
class RegisterPortalLink extends StatelessWidget {
  const RegisterPortalLink({super.key, required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Column(
      children: [
        BodySmallText(
          AppStrings.registerPrompt,
          textAlign: TextAlign.center,
          color: colors.textSecondary,
        ),
        SizedBox(height: context.spacing.xxs),
        Semantics(
          link: true,
          button: true,
          label: AppStrings.openPortal,
          child: InkWell(
            borderRadius: context.radius.sm,
            onTap: () => context.read<AuthBloc>().add(
              const RegistrationPortalRequested(),
            ),
            child: Container(
              constraints: BoxConstraints(minHeight: context.sizes.touchTarget),
              padding: context.padding.chip,
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: BodySmallText(
                      address,
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(width: context.spacing.xs),
                  Icon(
                    Icons.open_in_new_rounded,
                    size: context.sizes.iconSm,
                    color: colors.primary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
