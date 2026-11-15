import 'dart:io';

import 'package:background_downloader/background_downloader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:pos_software/src/core/constants/app_constants.dart';
import 'package:pos_software/src/data/services/transfer/background_transfer_service.dart';

class MockFileDownloader extends Mock implements FileDownloader {}

/// Stands in for the platform directories the picker and the plugin use.
class _FakePathProvider extends PathProviderPlatform {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => p.join(root, 'cache');

  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'support');

  @override
  Future<String?> getApplicationDocumentsPath() async =>
      p.join(root, 'documents');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;

  /// Deliberately outside both the system temp tree and the fake app
  /// directories, so it stands for a file the operator owns.
  late Directory userSpace;
  late Directory cache;
  late Directory uploads;
  late BackgroundTransferService service;

  // Task.baseDirectoryPath caches its answers for the life of the isolate, so
  // every test in this file shares one root.
  setUpAll(() {
    root = Directory.systemTemp.createTempSync('pos_upload_source');
    userSpace = Directory(
      p.join(Directory.current.path, 'build', 'pos_upload_source_user'),
    )..createSync(recursive: true);
    PathProviderPlatform.instance = _FakePathProvider(root.path);
  });

  tearDownAll(() {
    root.deleteSync(recursive: true);
    userSpace.deleteSync(recursive: true);
  });

  setUp(() {
    cache = Directory(p.join(root.path, 'cache', 'file_picker'))
      ..createSync(recursive: true);
    uploads = Directory(
      p.join(root.path, 'support', AppConstants.uploadSourceFolderName),
    );
    if (uploads.existsSync()) uploads.deleteSync(recursive: true);
    service = BackgroundTransferService(downloader: MockFileDownloader());
  });

  File pickedCopy(String name) =>
      File(p.join(cache.path, name))..writeAsStringSync('catalog rows');

  test('a picked copy is moved out of the cache directory', () async {
    final picked = pickedCopy('catalog.csv');

    final retained = await service.retainUploadSource(picked.path);

    expect(p.isWithin(uploads.path, retained), isTrue);
    expect(File(retained).readAsStringSync(), 'catalog rows');
    // Moved, not copied: no second half-gigabyte left behind in the cache.
    expect(picked.existsSync(), isFalse);
  });

  test('a file the user owns is left exactly where it is', () async {
    final outside = File(p.join(userSpace.path, 'sdcard_catalog.csv'))
      ..writeAsStringSync('rows');

    expect(await service.retainUploadSource(outside.path), outside.path);
    expect(outside.existsSync(), isTrue);
  });

  test('two uploads of the same name do not land on each other', () async {
    final first = await service.retainUploadSource(pickedCopy('a.csv').path);
    final second = await service.retainUploadSource(pickedCopy('a.csv').path);

    expect(first, isNot(second));
    expect(uploads.listSync(), hasLength(2));
  });

  test('a source already retained is not moved again', () async {
    final retained = await service.retainUploadSource(pickedCopy('a.csv').path);

    expect(await service.retainUploadSource(retained), retained);
    expect(uploads.listSync(), hasLength(1));
  });

  test('deleting a picked copy reaches the retained file too', () async {
    final retained = await service.retainUploadSource(pickedCopy('a.csv').path);

    await service.deletePickedCopy(retained);

    expect(File(retained).existsSync(), isFalse);
  });

  test('deleting never touches a file outside the app sandbox', () async {
    final outside = File(p.join(userSpace.path, 'sdcard_catalog.csv'))
      ..writeAsStringSync('rows');

    await service.deletePickedCopy(outside.path);

    expect(outside.existsSync(), isTrue);
  });

  test('pruning drops the sources no transfer refers to', () async {
    final kept = await service.retainUploadSource(pickedCopy('kept.csv').path);
    // What a crash between the move and the database write leaves behind.
    await service.retainUploadSource(pickedCopy('orphan.csv').path);

    await service.pruneUploadSources([kept]);

    expect(uploads.listSync().map((e) => e.path), [kept]);
  });

  test('pruning an empty folder is harmless', () async {
    await service.pruneUploadSources(const []);

    expect(uploads.existsSync(), isFalse);
  });
}
