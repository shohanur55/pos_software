import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../common/confirm_dialog.dart';

/// Asks before pausing an upload that would have to start over.
///
/// Pausing is normally free — a download keeps its place — so the dialog only
/// appears where it isn't: an upload, on a server that has told us it cannot
/// continue an interrupted one, that has already sent something worth losing.
/// Anywhere else this returns `true` without a dialog, because a confirmation
/// nobody needs is just another tap.
Future<bool> confirmPause(
  BuildContext context, {
  required TransferEntity transfer,
  required bool serverCannotResumeUploads,
}) async {
  final costly =
      serverCannotResumeUploads &&
      transfer.isUpload &&
      !transfer.resumesWhereItStopped &&
      transfer.transferredBytes > 0;
  if (!costly) return true;
  return showConfirmDialog(
    context,
    title: AppStrings.pauseUploadConfirmTitle,
    message: AppStrings.pauseUploadConfirmBody(
      ByteFormatter.format(transfer.transferredBytes),
    ),
    confirmLabel: AppStrings.pauseAnyway,
    cancelLabel: AppStrings.keepUploading,
    destructive: true,
  );
}
