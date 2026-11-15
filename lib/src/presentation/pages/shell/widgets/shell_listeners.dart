import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/auth/auth_bloc.dart';
import '../../../blocs/connectivity/connectivity_cubit.dart';
import '../../../blocs/files/files_bloc.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../router/routes.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/common/snackbars.dart';

/// Cross-bloc coordination for the signed-in area. Blocs never reference each
/// other; their side effects meet here.
class ShellListeners extends StatelessWidget {
  const ShellListeners({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        // One dropped connection should not need the user to retry by hand.
        BlocListener<ConnectivityCubit, ConnectivityStatus>(
          listenWhen: (previous, current) =>
              previous == ConnectivityStatus.offline &&
              current == ConnectivityStatus.online,
          listener: (context, state) {
            context.read<TransferBloc>().add(const ConnectionRestored());
            context.read<FilesBloc>().add(const FilesRefreshed());
          },
        ),
        BlocListener<TransferBloc, TransferState>(
          listenWhen: (previous, current) =>
              previous.notice != current.notice && current.notice != null,
          listener: _onTransferNotice,
        ),
        BlocListener<FilesBloc, FilesState>(
          listenWhen: (previous, current) =>
              previous.notice != current.notice && current.notice != null,
          listener: _onFilesNotice,
        ),
      ],
      child: child,
    );
  }

  void _onTransferNotice(BuildContext context, TransferState state) {
    final notice = state.notice!;
    void openTransfers() => context.goNamed(Routes.transfersName);
    switch (notice.kind) {
      case TransferNoticeKind.uploadCompleted:
        context.read<FilesBloc>().add(const FilesRefreshed());
        context.showAppSnackBar(
          AppStrings.uploadCompletedSnack(notice.subject ?? ''),
          tone: SnackBarTone.success,
          actionLabel: AppStrings.tabFiles,
          onAction: () => context.goNamed(Routes.filesName),
        );
      case TransferNoticeKind.downloadCompleted:
        context.showAppSnackBar(
          AppStrings.downloadCompletedSnack(notice.subject ?? ''),
          tone: SnackBarTone.success,
          actionLabel: AppStrings.view,
          onAction: openTransfers,
        );
      case TransferNoticeKind.autoResumed:
        context.showAppSnackBar(
          AppStrings.autoResumedSnack(notice.subject ?? ''),
        );
      case TransferNoticeKind.downloadStarted:
        context.showAppSnackBar(
          AppStrings.downloadStarted,
          actionLabel: AppStrings.viewTransfers,
          onAction: openTransfers,
        );
      case TransferNoticeKind.alreadyDownloading:
        context.showAppSnackBar(
          AppStrings.errorAlreadyDownloading,
          tone: SnackBarTone.warning,
          actionLabel: AppStrings.viewTransfers,
          onAction: openTransfers,
        );
      case TransferNoticeKind.resumeRestarting:
        context.showAppSnackBar(
          AppStrings.errorResumeFailed,
          tone: SnackBarTone.warning,
        );
      case TransferNoticeKind.unauthorized:
        context.read<AuthBloc>().add(const SessionExpired());
      case TransferNoticeKind.cannotOpen:
        context.showAppSnackBar(
          AppStrings.errorCannotOpen(notice.subject ?? ''),
          tone: SnackBarTone.error,
        );
      case TransferNoticeKind.actionFailed:
        context.showAppSnackBar(
          UiMessages.failureMessage(notice.failure),
          tone: SnackBarTone.error,
        );
    }
  }

  void _onFilesNotice(BuildContext context, FilesState state) {
    final notice = state.notice!;
    switch (notice.kind) {
      case FilesNoticeKind.deleted:
        context.showAppSnackBar(
          AppStrings.fileDeleted(notice.subject ?? ''),
          tone: SnackBarTone.success,
        );
      case FilesNoticeKind.deleteFailed || FilesNoticeKind.refreshFailed:
        context.showAppSnackBar(
          UiMessages.failureMessage(notice.failure),
          tone: SnackBarTone.error,
        );
    }
  }
}
