import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/base/failure.dart';
import '../../../core/base/result.dart';
import '../../../domain/entities/picked_file_entity.dart';
import '../../../domain/entities/upload_request_entity.dart';
import '../../../domain/entities/upload_validation_error.dart';
import '../../../domain/services/file_picker_service.dart';
import '../../../domain/usecases/files/validate_upload_file_use_case.dart';
import '../../../domain/usecases/transfers/start_upload_use_case.dart';
import '../common/ui_notice.dart';

part 'upload_event.dart';
part 'upload_state.dart';

/// Owns file selection and the start of an upload. Live progress is read
/// from `TransferBloc` using [UploadState.activeTransferId].
class UploadBloc extends Bloc<UploadEvent, UploadState> {
  UploadBloc(this._picker, this._validate, this._startUpload)
    : super(const UploadState()) {
    on<FilePickRequested>(_onPickRequested);
    on<FileCleared>((event, emit) => emit(const UploadState()));
    on<UploadSubmitted>(_onSubmitted);
    on<UploadFinishedAcknowledged>((event, emit) => emit(const UploadState()));
  }

  final FilePickerService _picker;
  final ValidateUploadFileUseCase _validate;
  final StartUploadUseCase _startUpload;
  int _noticeId = 0;

  Future<void> _onPickRequested(
    FilePickRequested event,
    Emitter<UploadState> emit,
  ) async {
    if (state.pickStatus == PickStatus.picking) return;
    emit(state.copyWith(pickStatus: PickStatus.picking));
    final PickedFileEntity? file;
    try {
      file = await _picker.pickUploadFile();
    } on Exception {
      emit(
        state.copyWith(
          pickStatus: PickStatus.idle,
          notice: UiNotice(UploadNoticeKind.pickerFailed, ++_noticeId),
        ),
      );
      return;
    }
    if (file == null) {
      emit(state.copyWith(pickStatus: PickStatus.idle));
      return;
    }
    final error = await _validate(file);
    emit(
      UploadState(
        selectedFile: file,
        validationError: error,
        notice: state.notice,
      ),
    );
  }

  Future<void> _onSubmitted(
    UploadSubmitted event,
    Emitter<UploadState> emit,
  ) async {
    final file = state.selectedFile;
    if (!state.canSubmit || file == null) return;
    emit(
      state.copyWith(submitStatus: SubmitStatus.starting, clearFailure: true),
    );

    // The file may have been moved or deleted since it was picked.
    final error = await _validate(file);
    if (error != null) {
      emit(
        state.copyWith(submitStatus: SubmitStatus.idle, validationError: error),
      );
      return;
    }
    final result = await _startUpload(
      UploadRequestEntity(
        filePath: file.path,
        fileName: file.name,
        sizeBytes: file.sizeBytes,
      ),
    );
    switch (result) {
      case Success(:final data):
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.started,
            activeTransferId: data.id,
          ),
        );
      case Error(:final error):
        emit(
          state.copyWith(
            submitStatus: SubmitStatus.failure,
            submitFailure: error.kind,
          ),
        );
    }
  }
}
