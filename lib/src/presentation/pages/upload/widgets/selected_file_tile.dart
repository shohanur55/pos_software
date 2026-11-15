import 'package:flutter/material.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/byte_formatter.dart';
import '../../../../domain/entities/picked_file_entity.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/common/file_type_icon.dart';
import '../../../widgets/typography/app_text.dart';

class SelectedFileTile extends StatelessWidget {
  const SelectedFileTile({
    super.key,
    required this.file,
    this.error,
    this.onRemove,
  });

  final PickedFileEntity file;
  final String? error;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Container(
      padding: context.padding.tile,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: context.radius.lg,
        border: Border.all(
          color: error == null ? colors.outline : colors.error,
          width: context.sizes.borderWidth,
        ),
      ),
      child: Row(
        children: [
          FileTypeIcon(fileName: file.name),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TitleText(file.name, maxLines: 2),
                SizedBox(height: context.spacing.xxs),
                BodySmallText(ByteFormatter.format(file.sizeBytes)),
                if (error != null) ...[
                  SizedBox(height: context.spacing.xs),
                  BodySmallText(error!, color: colors.error),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: AppStrings.uploadRemoveFile,
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
