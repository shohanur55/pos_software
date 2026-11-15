import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/domain/entities/upload_request_entity.dart';
import 'package:pos_software/src/domain/entities/upload_validation_error.dart';
import 'package:pos_software/src/domain/usecases/files/validate_upload_file_use_case.dart';
import 'package:pos_software/src/domain/usecases/transfers/start_upload_use_case.dart';
import 'package:pos_software/src/presentation/blocs/common/ui_notice.dart';
import 'package:pos_software/src/presentation/blocs/upload/upload_bloc.dart';

import '../../helpers/fixtures.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockFilePickerService picker;
  late MockFileInspector inspector;
  late MockTransferRepository transfers;

  setUpAll(
    () => registerFallbackValue(
      const UploadRequestEntity(filePath: '', fileName: '', sizeBytes: 0),
    ),
  );

  setUp(() {
    picker = MockFilePickerService();
    inspector = MockFileInspector();
    transfers = MockTransferRepository();
    when(() => inspector.exists(any())).thenAnswer((_) async => true);
    when(() => inspector.isReadable(any())).thenAnswer((_) async => true);
    when(() => inspector.length(any())).thenAnswer((_) async => 2048);
  });

  UploadBloc build() => UploadBloc(
    picker,
    ValidateUploadFileUseCase(inspector),
    StartUploadUseCase(transfers),
  );

  blocTest<UploadBloc, UploadState>(
    'picks and validates a file',
    setUp: () =>
        when(() => picker.pickUploadFile()).thenAnswer((_) async => csvFile),
    build: build,
    act: (bloc) => bloc.add(const FilePickRequested()),
    expect: () => [
      const UploadState(pickStatus: PickStatus.picking),
      const UploadState(selectedFile: csvFile),
    ],
    verify: (bloc) => expect(bloc.state.canSubmit, isTrue),
  );

  blocTest<UploadBloc, UploadState>(
    'keeps the previous selection when the picker is canceled',
    setUp: () =>
        when(() => picker.pickUploadFile()).thenAnswer((_) async => null),
    build: build,
    seed: () => const UploadState(selectedFile: csvFile),
    act: (bloc) => bloc.add(const FilePickRequested()),
    expect: () => [
      const UploadState(pickStatus: PickStatus.picking, selectedFile: csvFile),
      const UploadState(selectedFile: csvFile),
    ],
  );

  blocTest<UploadBloc, UploadState>(
    'reports picker errors without crashing',
    setUp: () =>
        when(() => picker.pickUploadFile()).thenThrow(Exception('platform')),
    build: build,
    act: (bloc) => bloc.add(const FilePickRequested()),
    expect: () => [
      const UploadState(pickStatus: PickStatus.picking),
      const UploadState(notice: UiNotice(UploadNoticeKind.pickerFailed, 1)),
    ],
  );

  blocTest<UploadBloc, UploadState>(
    'flags an invalid file and blocks submission',
    setUp: () {
      when(() => picker.pickUploadFile()).thenAnswer((_) async => csvFile);
      when(() => inspector.length(any())).thenAnswer((_) async => 0);
    },
    build: build,
    act: (bloc) => bloc
      ..add(const FilePickRequested())
      ..add(const UploadSubmitted()),
    expect: () => [
      const UploadState(pickStatus: PickStatus.picking),
      const UploadState(
        selectedFile: csvFile,
        validationError: UploadValidationError.empty,
      ),
    ],
    verify: (_) => verifyNever(() => transfers.startUpload(any())),
  );

  blocTest<UploadBloc, UploadState>(
    'starts the upload and follows the returned transfer',
    setUp: () =>
        when(() => transfers.startUpload(any()))
            .thenAnswer((_) async => Success(transfer(id: 'up-1'))),
    build: build,
    seed: () => const UploadState(selectedFile: csvFile),
    act: (bloc) => bloc.add(const UploadSubmitted()),
    expect: () => [
      const UploadState(
        selectedFile: csvFile,
        submitStatus: SubmitStatus.starting,
      ),
      const UploadState(
        selectedFile: csvFile,
        submitStatus: SubmitStatus.started,
        activeTransferId: 'up-1',
      ),
    ],
    verify: (_) => verify(
      () => transfers.startUpload(
        const UploadRequestEntity(
          filePath: '/tmp/catalog.csv',
          fileName: 'catalog.csv',
          sizeBytes: 2048,
        ),
      ),
    ).called(1),
  );

  blocTest<UploadBloc, UploadState>(
    'ignores a double tap while starting',
    setUp: () =>
        when(() => transfers.startUpload(any()))
            .thenAnswer((_) async => Success(transfer(id: 'up-1'))),
    build: build,
    seed: () => const UploadState(selectedFile: csvFile),
    act: (bloc) => bloc
      ..add(const UploadSubmitted())
      ..add(const UploadSubmitted()),
    verify: (_) => verify(() => transfers.startUpload(any())).called(1),
  );

  blocTest<UploadBloc, UploadState>(
    'surfaces start failures',
    setUp: () => when(
      () => transfers.startUpload(any()),
    ).thenAnswer((_) async => const Error(Failure(FailureKind.unauthorized))),
    build: build,
    seed: () => const UploadState(selectedFile: csvFile),
    act: (bloc) => bloc.add(const UploadSubmitted()),
    expect: () => [
      const UploadState(
        selectedFile: csvFile,
        submitStatus: SubmitStatus.starting,
      ),
      const UploadState(
        selectedFile: csvFile,
        submitStatus: SubmitStatus.failure,
        submitFailure: FailureKind.unauthorized,
      ),
    ],
  );

  blocTest<UploadBloc, UploadState>(
    'acknowledging the result resets the screen',
    build: build,
    seed: () => const UploadState(
      selectedFile: csvFile,
      submitStatus: SubmitStatus.started,
      activeTransferId: 'up-1',
    ),
    act: (bloc) => bloc.add(const UploadFinishedAcknowledged()),
    expect: () => [const UploadState()],
  );
}
