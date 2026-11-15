import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/transfer_entity.dart';
import '../../../../domain/entities/transfer_status.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import 'upload_progress_card.dart';
import 'upload_result_card.dart';

/// Live view of the started upload, read from the global [TransferBloc].
class UploadTransferSection extends StatelessWidget {
  const UploadTransferSection({super.key, required this.transferId});

  final String transferId;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<TransferBloc, TransferState, TransferEntity?>(
      selector: (state) => state.byId(transferId),
      builder: (context, transfer) {
        if (transfer == null) return const SizedBox.shrink();
        return switch (transfer.status) {
          TransferStatus.completed ||
          TransferStatus.failed ||
          TransferStatus.canceled => UploadResultCard(transfer: transfer),
          _ => UploadProgressCard(transfer: transfer),
        };
      },
    );
  }
}
