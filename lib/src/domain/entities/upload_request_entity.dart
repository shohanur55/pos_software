import 'package:equatable/equatable.dart';

class UploadRequestEntity extends Equatable {
  const UploadRequestEntity({
    required this.filePath,
    required this.fileName,
    required this.sizeBytes,
  });

  final String filePath;
  final String fileName;
  final int sizeBytes;

  @override
  List<Object?> get props => [filePath, fileName, sizeBytes];
}
