import 'package:flutter/material.dart';

import '../../../core/constants/transfer_constants.dart';
import '../../../core/utils/file_name_utils.dart';
import '../../theme/app_colors.dart';
import '../../theme/theme_extensions.dart';

enum FileKind { document, image, video, other }

/// Square tile with a type icon, so a catalog, a photo and a video are told
/// apart without reading the file name.
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.fileName, this.size});

  final String fileName;
  final double? size;

  static FileKind kindOf(String fileName) {
    final extension = FileNameUtils.extensionOf(fileName);
    return switch (extension) {
      _ when TransferConstants.imageExtensions.contains(extension) =>
        FileKind.image,
      _ when TransferConstants.videoExtensions.contains(extension) =>
        FileKind.video,
      _ when TransferConstants.documentExtensions.contains(extension) =>
        FileKind.document,
      _ => FileKind.other,
    };
  }

  static IconData iconFor(String fileName) => switch (kindOf(fileName)) {
    FileKind.image => Icons.image_outlined,
    FileKind.video => Icons.movie_outlined,
    FileKind.document => Icons.table_chart_outlined,
    FileKind.other => Icons.insert_drive_file_outlined,
  };

  static (Color foreground, Color background) colorsFor(
    AppColors colors,
    String fileName,
  ) => switch (kindOf(fileName)) {
    FileKind.image => (colors.accentImage, colors.accentImageContainer),
    FileKind.video => (colors.accentVideo, colors.accentVideoContainer),
    FileKind.document => (
      colors.accentDocument,
      colors.accentDocumentContainer,
    ),
    FileKind.other => (colors.onPrimaryContainer, colors.primaryContainer),
  };

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = colorsFor(context.color, fileName);
    final dimension = size ?? context.sizes.avatar;
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.radius.md,
      ),
      child: Icon(
        iconFor(fileName),
        color: foreground,
        size: context.sizes.iconMd,
      ),
    );
  }
}
