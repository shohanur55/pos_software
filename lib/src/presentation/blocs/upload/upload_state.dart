part of 'upload_bloc.dart';

enum PickStatus { idle, picking }

enum SubmitStatus { idle, starting, started, failure }

enum UploadNoticeKind { pickerFailed }

final class UploadState extends Equatable {
  const UploadState({
    this.pickStatus = PickStatus.idle,
    this.selectedFile,
    this.validationError,
    this.submitStatus = SubmitStatus.idle,
    this.submitFailure,
    this.activeTransferId,
    this.notice,
  });

  final PickStatus pickStatus;
  final PickedFileEntity? selectedFile;
  final UploadValidationError? validationError;
  final SubmitStatus submitStatus;
  final FailureKind? submitFailure;

  /// Transfer to follow in [TransferBloc] for live progress.
  final String? activeTransferId;
  final UiNotice<UploadNoticeKind>? notice;

  bool get canSubmit =>
      selectedFile != null &&
      validationError == null &&
      pickStatus == PickStatus.idle &&
      submitStatus != SubmitStatus.starting &&
      activeTransferId == null;

  UploadState copyWith({
    PickStatus? pickStatus,
    PickedFileEntity? selectedFile,
    UploadValidationError? validationError,
    SubmitStatus? submitStatus,
    FailureKind? submitFailure,
    String? activeTransferId,
    UiNotice<UploadNoticeKind>? notice,
    bool clearFile = false,
    bool clearValidation = false,
    bool clearFailure = false,
    bool clearTransfer = false,
  }) {
    return UploadState(
      pickStatus: pickStatus ?? this.pickStatus,
      selectedFile: clearFile ? null : (selectedFile ?? this.selectedFile),
      validationError: clearValidation
          ? null
          : (validationError ?? this.validationError),
      submitStatus: submitStatus ?? this.submitStatus,
      submitFailure: clearFailure
          ? null
          : (submitFailure ?? this.submitFailure),
      activeTransferId: clearTransfer
          ? null
          : (activeTransferId ?? this.activeTransferId),
      notice: notice ?? this.notice,
    );
  }

  @override
  List<Object?> get props => [
    pickStatus,
    selectedFile,
    validationError,
    submitStatus,
    submitFailure,
    activeTransferId,
    notice,
  ];
}
