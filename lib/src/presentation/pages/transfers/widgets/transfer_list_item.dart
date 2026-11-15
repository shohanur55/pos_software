import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/transfer_entity.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
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
    return BlocSelector<TransferBloc, TransferState, TransferEntity?>(
      selector: (state) => state.byId(transferId),
      builder: (context, transfer) {
        if (transfer == null) return const SizedBox.shrink();
        return TransferTile(
          transfer: transfer,
          highlighted: highlighted,
          onAction: (action) =>
              context.read<TransferBloc>().add(switch (action) {
                TransferAction.pause => TransferPaused(transfer.id),
                TransferAction.resume => TransferResumed(transfer.id),
                TransferAction.cancel => TransferCanceled(transfer.id),
                TransferAction.retry => TransferRetried(transfer.id),
                TransferAction.open => TransferOpened(transfer.id),
                TransferAction.remove => TransferRemoved(transfer.id),
              }),
        );
      },
    );
  }
}
