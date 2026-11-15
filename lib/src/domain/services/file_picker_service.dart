import '../entities/picked_file_entity.dart';

/// Picks a file from the device. Returns `null` when the user cancels.
abstract interface class FilePickerService {
  Future<PickedFileEntity?> pickUploadFile();
}
