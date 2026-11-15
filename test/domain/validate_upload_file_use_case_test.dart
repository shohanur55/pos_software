import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/constants/transfer_constants.dart';
import 'package:pos_software/src/domain/entities/picked_file_entity.dart';
import 'package:pos_software/src/domain/entities/upload_validation_error.dart';
import 'package:pos_software/src/domain/usecases/files/validate_upload_file_use_case.dart';

import '../helpers/fixtures.dart';
import '../helpers/mocks.dart';

void main() {
  late MockFileInspector inspector;
  late ValidateUploadFileUseCase validate;

  setUp(() {
    inspector = MockFileInspector();
    validate = ValidateUploadFileUseCase(inspector);
    when(() => inspector.exists(any())).thenAnswer((_) async => true);
    when(() => inspector.isReadable(any())).thenAnswer((_) async => true);
    when(() => inspector.length(any())).thenAnswer((_) async => 2048);
  });

  test('accepts a readable, non-empty file of an allowed type', () async {
    expect(await validate(csvFile), isNull);
  });

  test('rejects a missing selection', () async {
    expect(await validate(null), UploadValidationError.missing);
  });

  test('rejects unsupported extensions before touching the disk', () async {
    const pdf = PickedFileEntity(
      path: '/tmp/a.pdf',
      name: 'a.pdf',
      sizeBytes: 1,
      extension: 'pdf',
    );
    expect(await validate(pdf), UploadValidationError.unsupportedType);
    verifyNever(() => inspector.exists(any()));
  });

  test('accepts upper-case extensions', () async {
    const video = PickedFileEntity(
      path: '/tmp/A.MP4',
      name: 'A.MP4',
      sizeBytes: 1,
      extension: 'MP4',
    );
    expect(await validate(video), isNull);
  });

  test('rejects missing or unreadable files', () async {
    when(() => inspector.exists(any())).thenAnswer((_) async => false);
    expect(await validate(csvFile), UploadValidationError.unreadable);
    when(() => inspector.exists(any())).thenAnswer((_) async => true);
    when(() => inspector.isReadable(any())).thenAnswer((_) async => false);
    expect(await validate(csvFile), UploadValidationError.unreadable);
  });

  test('rejects empty files', () async {
    when(() => inspector.length(any())).thenAnswer((_) async => 0);
    expect(await validate(csvFile), UploadValidationError.empty);
  });

  test('enforces the 512 MB limit using the real size on disk', () async {
    when(() => inspector.length(any()))
        .thenAnswer((_) async => TransferConstants.maxUploadBytes);
    expect(await validate(csvFile), isNull);
    when(() => inspector.length(any()))
        .thenAnswer((_) async => TransferConstants.maxUploadBytes + 1);
    expect(await validate(csvFile), UploadValidationError.tooLarge);
  });

  test('treats file system errors as unreadable', () async {
    when(() => inspector.length(any())).thenThrow(const FormatException('io'));
    expect(await validate(csvFile), UploadValidationError.unreadable);
  });
}
