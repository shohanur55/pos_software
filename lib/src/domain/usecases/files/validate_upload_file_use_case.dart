import '../../../core/constants/transfer_constants.dart';
import '../../entities/picked_file_entity.dart';
import '../../entities/upload_validation_error.dart';
import '../../services/file_inspector.dart';

/// Returns the first rule the file breaks, or `null` when it can be uploaded.
final class ValidateUploadFileUseCase {
  ValidateUploadFileUseCase(this.inspector);

  final FileInspector inspector;

  Future<UploadValidationError?> call(PickedFileEntity? file) async {
    if (file == null) return UploadValidationError.missing;
    if (!TransferConstants.allowedUploadExtensions.contains(
      file.extension.toLowerCase(),
    )) {
      return UploadValidationError.unsupportedType;
    }
    try {
      if (!await inspector.exists(file.path) ||
          !await inspector.isReadable(file.path)) {
        return UploadValidationError.unreadable;
      }
      final size = await inspector.length(file.path);
      if (size <= 0) return UploadValidationError.empty;
      if (size > TransferConstants.maxUploadBytes) {
        return UploadValidationError.tooLarge;
      }
    } on Exception {
      return UploadValidationError.unreadable;
    }
    return null;
  }
}
