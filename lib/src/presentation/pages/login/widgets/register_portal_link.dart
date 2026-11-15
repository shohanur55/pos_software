import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../router/routes.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/typography/app_text.dart';

/// A sign-up prompt on the login screen. Tapping it opens the server's own
/// registration page inside the app through a WebView, so the user never
/// leaves POS Software to create an account.
class RegisterPortalLink extends StatelessWidget {
  const RegisterPortalLink({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Material(
      color: Colors.transparent,
      borderRadius: context.radius.lg,
      child: InkWell(
        borderRadius: context.radius.lg,
        onTap: () => context.goNamed(Routes.signupName),
        child: Ink(
          decoration: BoxDecoration(
            color: colors.surfaceContainer,
            borderRadius: context.radius.lg,
            border: Border.all(color: colors.outline.withValues(alpha: 0.4)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: context.spacing.lg,
            vertical: context.spacing.md,
          ),
          child: Semantics(
            link: true,
            button: true,
            label: AppStrings.openPortal,
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: context.radius.md,
                  ),
                  child: Icon(
                    Icons.person_add_alt_1_rounded,
                    color: colors.primary,
                    size: context.sizes.iconMd,
                  ),
                ),
                SizedBox(width: context.spacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BodySmallText(
                        AppStrings.registerPrompt,
                        color: colors.textSecondary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      BodyMediumText(
                        AppStrings.registerCta,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.spacing.sm),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colors.primary,
                  size: context.sizes.iconMd,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
