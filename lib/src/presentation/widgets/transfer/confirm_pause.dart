import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/utils/byte_formatter.dart';
import '../../../domain/entities/transfer_entity.dart';
import '../common/confirm_dialog.dart';

/// Confirms before pausing an upload that would have to start over.
///
/// Pausing is normally free (a download keeps its place), so the dialog only
/// appears for an upload on a server that can't resume and has already sent
/// something worth losing. Everywhere else this returns true without a dialog.
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
