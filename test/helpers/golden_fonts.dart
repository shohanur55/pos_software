import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Loads real fonts so golden images show text instead of placeholder blocks.
///
/// The files ship with the Flutter SDK, so the app itself bundles no fonts.
Future<void> loadGoldenFonts() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final fonts = _materialFontsDirectory();
  if (fonts == null) return;

  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    var found = false;
    for (final name in files) {
      final file = File(p.join(fonts.path, name));
      if (!file.existsSync()) continue;
      loader.addFont(file.readAsBytes().then(ByteData.sublistView));
      found = true;
    }
    if (found) await loader.load();
  }

  await load('Roboto', const [
    'Roboto-Regular.ttf',
    'Roboto-Medium.ttf',
    'Roboto-Bold.ttf',
  ]);
  await load('MaterialIcons', const ['MaterialIcons-Regular.otf']);
}

/// Walks up from the Dart executable to the SDK's `bin/cache/artifacts`.
Directory? _materialFontsDirectory() {
  var directory = File(Platform.resolvedExecutable).parent;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = Directory(
      p.join(directory.path, 'artifacts', 'material_fonts'),
    );
    if (candidate.existsSync()) return candidate;
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  return null;
}
