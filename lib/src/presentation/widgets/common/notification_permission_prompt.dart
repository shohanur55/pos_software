import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../blocs/notification_permission/notification_permission_cubit.dart';
import 'confirm_dialog.dart';

/// Asks for notification permission with a short rationale the first time a
/// transfer starts. Transfers proceed whatever the answer is.
Future<void> ensureNotificationPermission(BuildContext context) async {
  final cubit = context.read<NotificationPermissionCubit>();
  if (cubit.state.status == null) await cubit.refresh();
  if (!cubit.state.needsRationale || !context.mounted) return;
  final allow = await showConfirmDialog(
    context,
    title: AppStrings.notificationRationaleTitle,
    message: AppStrings.notificationRationaleBody,
    confirmLabel: AppStrings.allow,
    cancelLabel: AppStrings.notNow,
  );
  if (allow) {
    await cubit.request();
  } else {
    cubit.declined();
  }
}
