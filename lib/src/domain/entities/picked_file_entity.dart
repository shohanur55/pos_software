import 'package:equatable/equatable.dart';

class PickedFileEntity extends Equatable {
  const PickedFileEntity({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.extension,
  });

  final String path;
  final String name;
  final int sizeBytes;

  /// Lower-case, without the dot.
  final String extension;

  @override
  List<Object?> get props => [path, name, sizeBytes, extension];
}
