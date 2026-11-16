import '../../repositories/transfer_repository.dart';

/// Whether the configured server can continue an interrupted upload.
///
/// `null` until the question has been asked, which happens alongside the first
/// upload.
final class WatchUploadResumeSupportUseCase {
  WatchUploadResumeSupportUseCase(this.repository);

  final TransferRepository repository;

  bool? current() => repository.uploadResumeSupport;

  Stream<bool?> call() => repository.watchUploadResumeSupport();
}
