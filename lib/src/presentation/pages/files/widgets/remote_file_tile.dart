import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../domain/entities/remote_file_entity.dart';
import '../../../../domain/entities/transfer_entity.dart';
import '../../../blocs/files/files_bloc.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/common/confirm_dialog.dart';
import '../../../widgets/common/file_type_icon.dart';
import '../../../widgets/typography/app_text.dart';
import 'file_download_action.dart';

class RemoteFileTile extends StatelessWidget {
  const RemoteFileTile({super.key, required this.file});

  final RemoteFileEntity file;

  String _subtitle(BuildContext context) {
    final size = file.sizeBytes;
    final date = file.uploadedAt;
    final sizeText = size == null ? null : ByteFormatter.format(size);
    final dateText = date == null
        ? null
        : DateFormat.yMMMd().add_jm().format(date.toLocal());
    if (sizeText != null && dateText != null) {
      return AppStrings.fileSizeAndDate(sizeText, dateText);
    }
    return sizeText ?? dateText ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    final subtitle = _subtitle(context);
    return Container(
      padding: context.padding.tile,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: colors.outline,
          width: context.sizes.borderWidth,
        ),
      ),
      // Only this tile rebuilds while its own download ticks.
      child: BlocSelector<TransferBloc, TransferState, TransferEntity?>(
        selector: (state) => state.latestDownloadFor(file.name),
        builder: (context, download) => Row(
          children: [
            FileTypeIcon(fileName: file.name),
            SizedBox(width: context.spacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TitleText(file.name, maxLines: 2),
                  if (subtitle.isNotEmpty) ...[
                    SizedBox(height: context.spacing.xxs),
                    BodySmallText(subtitle, maxLines: 2),
                  ],
                  if (download != null && download.status.isInProgress) ...[
                    SizedBox(height: context.spacing.sm),
                    InlineDownloadProgress(transfer: download),
                  ],
                ],
              ),
            ),
            SizedBox(width: context.spacing.xs),
            FileDownloadAction(file: file, download: download),
            _FileMenu(file: file),
          ],
        ),
      ),
    );
  }
}

enum _FileMenuAction { delete }

class _FileMenu extends StatelessWidget {
  const _FileMenu({required this.file});

  final RemoteFileEntity file;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: AppStrings.deleteConfirmTitle,
      message: AppStrings.deleteConfirmBody(file.name),
      confirmLabel: AppStrings.delete,
      destructive: true,
    );
    if (confirmed && context.mounted) {
      context.read<FilesBloc>().add(FileDeleteRequested(file.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_FileMenuAction>(
      tooltip: AppStrings.moreOptions,
      onSelected: (action) => switch (action) {
        _FileMenuAction.delete => _confirmDelete(context),
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: _FileMenuAction.delete,
          child: ListTile(
            leading: Icon(
              Icons.delete_outline_rounded,
              color: context.color.error,
            ),
            title: BodyLargeText(AppStrings.delete, color: context.color.error),
          ),
        ),
      ],
    );
  }
}
