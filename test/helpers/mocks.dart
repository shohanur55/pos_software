import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/domain/repositories/authentication_repository.dart';
import 'package:pos_software/src/domain/repositories/remote_files_repository.dart';
import 'package:pos_software/src/domain/repositories/transfer_repository.dart';
import 'package:pos_software/src/domain/services/file_inspector.dart';
import 'package:pos_software/src/domain/services/file_picker_service.dart';

class MockAuthenticationRepository extends Mock
    implements AuthenticationRepository {}

class MockRemoteFilesRepository extends Mock implements RemoteFilesRepository {}

class MockTransferRepository extends Mock implements TransferRepository {}

class MockFilePickerService extends Mock implements FilePickerService {}

class MockFileInspector extends Mock implements FileInspector {}
