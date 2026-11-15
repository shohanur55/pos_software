import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/upload/upload_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/common/notification_permission_prompt.dart';
import '../../../widgets/typography/app_text.dart';
import 'pick_file_card.dart';
import 'selected_file_tile.dart';

/// File selection, validation and the Upload button.
class UploadFormSection extends StatelessWidget {
  const UploadFormSection({super.key});

  Future<void> _submit(BuildContext context) async {
    final bloc = context.read<UploadBloc>();
    unawaited(HapticFeedback.mediumImpact());
    await ensureNotificationPermission(context);
    bloc.add(const UploadSubmitted());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UploadBloc, UploadState>(
      buildWhen: (previous, current) =>
          previous != current && current.activeTransferId == null,
      builder: (context, state) {
        final colors = context.color;
        final file = state.selectedFile;
        final starting = state.submitStatus == SubmitStatus.starting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PickFileCard(isPicking: state.pickStatus == PickStatus.picking),
            if (file != null) ...[
              SizedBox(height: context.spacing.lg),
              SelectedFileTile(
                file: file,
                error: state.validationError == null
                    ? null
                    : UiMessages.validationMessage(state.validationError!),
                onRemove: starting
                    ? null
                    : () => context.read<UploadBloc>().add(const FileCleared()),
              ),
            ],
            if (state.submitStatus == SubmitStatus.failure) ...[
              SizedBox(height: context.spacing.md),
              BodyMediumText(
                UiMessages.failureMessage(state.submitFailure),
                color: colors.error,
              ),
            ],
            SizedBox(height: context.spacing.lg),
            FilledButton.icon(
              onPressed: state.canSubmit ? () => _submit(context) : null,
              icon: starting
                  ? SizedBox.square(
                      dimension: context.sizes.iconSm,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: LabelText(
                starting ? AppStrings.uploadStarting : AppStrings.uploadButton,
                color: state.canSubmit ? colors.onPrimary : null,
              ),
            ),
          ],
        );
      },
    );
  }
}
