part of 'upload_bloc.dart';

sealed class UploadEvent extends Equatable {
  const UploadEvent();

  @override
  List<Object?> get props => [];
}

final class FilePickRequested extends UploadEvent {
  const FilePickRequested();
}

final class FileCleared extends UploadEvent {
  const FileCleared();
}

final class UploadSubmitted extends UploadEvent {
  const UploadSubmitted();
}

/// The user saw the result of the last upload and wants to start over.
final class UploadFinishedAcknowledged extends UploadEvent {
  const UploadFinishedAcknowledged();
}
