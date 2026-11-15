import 'package:equatable/equatable.dart';

class RemoteFileEntity extends Equatable {
  const RemoteFileEntity({
    required this.name,
    required this.url,
    this.sizeBytes,
    this.uploadedAt,
  });

  final String name;

  /// Absolute download URL.
  final String url;
  final int? sizeBytes;
  final DateTime? uploadedAt;

  @override
  List<Object?> get props => [name, url, sizeBytes, uploadedAt];
}
