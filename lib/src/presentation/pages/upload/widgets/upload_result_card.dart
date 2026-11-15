import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../domain/entities/transfer_entity.dart';
import '../../../../domain/entities/transfer_status.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../blocs/upload/upload_bloc.dart';
import '../../../router/routes.dart';
import '../../../theme/theme_extensions.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/typography/app_text.dart';

/// Final state of an upload: success with next steps, or failure with retry.
class UploadResultCard extends StatelessWidget {
  const UploadResultCard({super.key, required this.transfer});

  final TransferEntity transfer;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final succeeded = transfer.status == TransferStatus.completed;
    final uploadBloc = context.read<UploadBloc>();

    final message = switch (transfer.status) {
      TransferStatus.completed => AppStrings.uploadDone,
      TransferStatus.canceled => AppStrings.statusCanceled,
      _ => UiMessages.transferErrorMessage(transfer.errorKind),
    };

    return Card(
      child: Padding(
        padding: context.padding.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              succeeded
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
              size: context.sizes.iconXl,
              color: succeeded ? colors.success : colors.error,
            ),
            SizedBox(height: context.spacing.md),
            HeadingMediumText(message, textAlign: TextAlign.center),
            SizedBox(height: context.spacing.xs),
            BodyMediumText(
              transfer.remoteFileName ?? transfer.fileName,
              textAlign: TextAlign.center,
              color: colors.textSecondary,
            ),
            SizedBox(height: context.spacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: context.spacing.md,
              runSpacing: context.spacing.sm,
              children: succeeded
                  ? [
                      FilledButton.icon(
                        onPressed: () => context.goNamed(Routes.filesName),
                        icon: const Icon(Icons.folder_open_rounded),
                        label: LabelText(
                          AppStrings.uploadViewInFiles,
                          color: colors.onPrimary,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () =>
                            uploadBloc.add(const UploadFinishedAcknowledged()),
                        child: LabelText(
                          AppStrings.uploadAnother,
                          color: colors.primary,
                        ),
                      ),
                    ]
                  : [
                      FilledButton.icon(
                        onPressed: () => context.read<TransferBloc>().add(
                          TransferRetried(transfer.id),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: LabelText(
                          AppStrings.retry,
                          color: colors.onPrimary,
                        ),
                      ),
                      OutlinedButton(
                        onPressed: () => uploadBloc
                          ..add(const UploadFinishedAcknowledged())
                          ..add(const FilePickRequested()),
                        child: LabelText(
                          AppStrings.uploadChooseAnother,
                          color: colors.primary,
                        ),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
