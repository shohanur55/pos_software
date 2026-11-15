import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/connectivity/connectivity_cubit.dart';
import '../../../blocs/notification_permission/notification_permission_cubit.dart';
import '../../../widgets/common/info_banner.dart';

/// At most one status banner at a time, so stacked banners never crowd out
/// the page on short screens. Being offline matters more than notifications.
class ShellStatusBanner extends StatelessWidget {
  const ShellStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final offline = context.select(
      (ConnectivityCubit cubit) => cubit.state == ConnectivityStatus.offline,
    );
    if (offline) {
      return const InfoBanner(
        icon: Icons.wifi_off_rounded,
        tone: InfoBannerTone.warning,
        message: AppStrings.offlineBanner,
      );
    }
    final notificationsOff = context.select(
      (NotificationPermissionCubit cubit) => cubit.state.showDeniedBanner,
    );
    if (!notificationsOff) return const SizedBox.shrink();
    final cubit = context.read<NotificationPermissionCubit>();
    return InfoBanner(
      icon: Icons.notifications_off_outlined,
      message: AppStrings.notificationsOffBanner,
      actionLabel: AppStrings.openSettings,
      onAction: cubit.openSettings,
      dismissTooltip: AppStrings.dismiss,
      onDismiss: cubit.dismissBanner,
    );
  }
}
