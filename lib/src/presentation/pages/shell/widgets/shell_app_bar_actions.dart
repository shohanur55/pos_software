import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../router/routes.dart';
import '../../../widgets/common/confirm_dialog.dart';
import '../../../widgets/typography/app_text.dart';

/// Transfers badge and the account menu, shown in every tab's AppBar.
class ShellAppBarActions extends StatelessWidget {
  const ShellAppBarActions({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [TransfersBadgeButton(), _AccountMenu()],
    );
  }
}

class TransfersBadgeButton extends StatelessWidget {
  const TransfersBadgeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final count = context.select((TransferBloc bloc) => bloc.state.activeCount);
    return IconButton(
      tooltip: AppStrings.transfersBadgeTooltip(count),
      onPressed: () => context.goNamed(Routes.transfersName),
      icon: Badge.count(
        count: count,
        isLabelVisible: count > 0,
        child: const Icon(Icons.swap_vert_rounded),
      ),
    );
  }
}

enum _AccountAction { logout }

class _AccountMenu extends StatelessWidget {
  const _AccountMenu();

  Future<void> _confirmLogout(BuildContext context) async {
    final active = context.read<TransferBloc>().state.activeCount;
    final message = active > 0
        ? '${AppStrings.logoutConfirmBody} ${AppStrings.logoutConfirmActive(active)}'
        : AppStrings.logoutConfirmBody;
    final confirmed = await showConfirmDialog(
      context,
      title: AppStrings.logoutConfirmTitle,
      message: message,
      confirmLabel: AppStrings.logout,
      destructive: active > 0,
    );
    if (confirmed && context.mounted) {
      context.read<AuthBloc>().add(const LogoutRequested());
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AccountAction>(
      tooltip: AppStrings.moreOptions,
      onSelected: (action) => switch (action) {
        _AccountAction.logout => _confirmLogout(context),
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _AccountAction.logout,
          child: ListTile(
            leading: Icon(Icons.logout_rounded),
            title: BodyLargeText(AppStrings.logout),
          ),
        ),
      ],
    );
  }
}
