import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../../theme/theme_extensions.dart';
import 'transfer_action.dart';

class TransferActionButtons extends StatelessWidget {
  const TransferActionButtons({
    super.key,
    required this.transfer,
    required this.onAction,
    this.exclude = const {},
  });

  final TransferEntity transfer;
  final ValueChanged<TransferAction> onAction;
  final Set<TransferAction> exclude;

  @override
  Widget build(BuildContext context) {
    final actions = transfer.availableActions.where(
      (action) => !exclude.contains(action),
    );
    return Wrap(
      spacing: context.spacing.xs,
      children: [
        for (final action in actions)
          IconButton(
            tooltip: _label(context, action),
            icon: Icon(_icon(action)),
            color: action == TransferAction.cancel
                ? context.color.error
                : context.color.primary,
            onPressed: () => onAction(action),
          ),
      ],
    );
  }

  static IconData _icon(TransferAction action) => switch (action) {
    TransferAction.pause => Icons.pause_rounded,
    TransferAction.resume => Icons.play_arrow_rounded,
    TransferAction.cancel => Icons.close_rounded,
    TransferAction.retry => Icons.refresh_rounded,
    TransferAction.open => Icons.open_in_new_rounded,
    TransferAction.remove => Icons.delete_outline_rounded,
  };

  static String _label(BuildContext context, TransferAction action) {
    return switch (action) {
      TransferAction.pause => AppStrings.pause,
      TransferAction.resume => AppStrings.resume,
      TransferAction.cancel => AppStrings.cancel,
      TransferAction.retry => AppStrings.retry,
      TransferAction.open => AppStrings.open,
      TransferAction.remove => AppStrings.remove,
    };
  }
}
