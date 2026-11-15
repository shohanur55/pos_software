import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../blocs/transfer/transfer_bloc.dart';
import '../../blocs/upload/upload_bloc.dart';
import '../../theme/theme_extensions.dart';
import '../../widgets/common/constrained_content.dart';
import '../../widgets/common/snackbars.dart';
import '../../widgets/typography/app_text.dart';
import '../shell/widgets/shell_app_bar_actions.dart';
import 'widgets/background_hint.dart';
import 'widgets/upload_form_section.dart';
import 'widgets/upload_transfer_section.dart';

class UploadPage extends StatelessWidget {
  const UploadPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<UploadBloc, UploadState>(
          listenWhen: (previous, current) =>
              previous.notice != current.notice && current.notice != null,
          listener: (context, state) => context.showAppSnackBar(
            AppStrings.errorPicker,
            tone: SnackBarTone.error,
          ),
        ),
        // The followed transfer was removed from history: start over.
        BlocListener<TransferBloc, TransferState>(
          listenWhen: (previous, current) {
            final id = context.read<UploadBloc>().state.activeTransferId;
            return id != null &&
                previous.byId(id) != null &&
                current.byId(id) == null;
          },
          listener: (context, state) => context.read<UploadBloc>().add(
            const UploadFinishedAcknowledged(),
          ),
        ),
      ],
      child: Scaffold(
        appBar: AppBar(
          title: const HeadingMediumText(AppStrings.uploadTitle, maxLines: 1),
          actions: const [ShellAppBarActions()],
        ),
        body: SafeArea(
          top: false,
          child: ConstrainedContent(
            child: ListView(
              padding: context.padding.list,
              children: [
                BlocSelector<UploadBloc, UploadState, String?>(
                  selector: (state) => state.activeTransferId,
                  builder: (context, transferId) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    // Height changes between the two, so animate size as well.
                    layoutBuilder: (current, previous) => Stack(
                      alignment: Alignment.topCenter,
                      children: [...previous, ?current],
                    ),
                    child: transferId == null
                        ? const UploadFormSection(key: ValueKey('form'))
                        : UploadTransferSection(
                            key: const ValueKey('transfer'),
                            transferId: transferId,
                          ),
                  ),
                ),
                SizedBox(height: context.spacing.lg),
                const BackgroundHint(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
