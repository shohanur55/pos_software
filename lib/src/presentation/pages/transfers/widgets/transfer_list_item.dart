import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/transfer_entity.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../widgets/transfer/confirm_pause.dart';
import '../../../widgets/transfer/transfer_action.dart';
import '../../../widgets/transfer/transfer_tile.dart';

/// Binds one [TransferTile] to [TransferBloc]; only this item rebuilds when
/// its transfer changes.
class TransferListItem extends StatelessWidget {
  const TransferListItem({
    super.key,
    required this.transferId,
    this.highlighted = false,
  });

  final String transferId;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TransferBloc, TransferState, (TransferEntity?, bool)>(
      selector: (state) =>
          (state.byId(transferId), state.uploadsRestartFromStart),
      builder: (context, selected) {
        final (transfer, uploadsRestart) = selected;
        if (transfer == null) return const SizedBox.shrink();
        return TransferTile(
          transfer: transfer,
          highlighted: highlighted,
          serverCannotResumeUploads: uploadsRestart,
          onAction: (action) => _onAction(
            context,
            transfer: transfer,
            action: action,
            uploadsRestart: uploadsRestart,
          ),
        );
      },
    );
  }

  Future<void> _onAction(
    BuildContext context, {
    required TransferEntity transfer,
    required TransferAction action,
    required bool uploadsRestart,
  }) async {
    final bloc = context.read<TransferBloc>();
    if (action == TransferAction.pause) {
      final go = await confirmPause(
        context,
        transfer: transfer,
        serverCannotResumeUploads: uploadsRestart,
      );
      if (!go) return;
      bloc.add(TransferPaused(transfer.id));
      return;
    }
    bloc.add(switch (action) {
      TransferAction.resume => TransferResumed(transfer.id),
      TransferAction.cancel => TransferCanceled(transfer.id),
      TransferAction.retry => TransferRetried(transfer.id),
      TransferAction.open => TransferOpened(transfer.id),
      TransferAction.remove => TransferRemoved(transfer.id),
      TransferAction.pause => TransferPaused(transfer.id),
    });
  }
}
