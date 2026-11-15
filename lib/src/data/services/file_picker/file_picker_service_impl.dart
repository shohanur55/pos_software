import 'package:file_picker/file_picker.dart';

import '../../../core/constants/transfer_constants.dart';
import '../../../core/utils/file_name_utils.dart';
import '../../../domain/entities/picked_file_entity.dart';
import '../../../domain/services/file_picker_service.dart';

/// Picks by path only: file bytes are never loaded into memory.
class FilePickerServiceImpl implements FilePickerService {
  @override
  Future<PickedFileEntity?> pickUploadFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: TransferConstants.allowedUploadExtensions.toList(),
    );
    final path = file?.path;
    if (file == null || path == null) return null;
    return PickedFileEntity(
      path: path,
      name: file.name,
      sizeBytes: await file.length() ?? 0,
      extension: FileNameUtils.extensionOf(file.name),
    );
  }
}
