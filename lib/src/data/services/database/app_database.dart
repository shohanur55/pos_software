import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens and migrates the local database.
///
/// A POS terminal is regularly offline, so transfer history and the file list
/// live on the device and the app works from them until the server answers.
class AppDatabase {
  AppDatabase({DatabaseFactory? factory, String? path})
    : _factory = factory ?? databaseFactory,
      _path = path ?? '';

  /// 1 — first release.
  /// 2 — `pauseReason` and `resumeFromByte`, for transfers parked by a dropped
  ///     connection and for uploads that continue from an offset.
  static const int schemaVersion = 2;
  static const String fileName = 'pos_transfers.db';

  static const String transfersTable = 'transfers';
  static const String cachedFilesTable = 'cached_files';

  final DatabaseFactory _factory;
  final String _path;
  Future<Database>? _opening;

  /// Opened once and shared; concurrent callers await the same future.
  Future<Database> get database => _opening ??= _open();

  Future<Database> _open() async {
    final path = _path.isNotEmpty
        ? _path
        : p.join(await _factory.getDatabasesPath(), fileName);
    return _factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (db, version) => _createSchema(db),
        onUpgrade: _upgrade,
      ),
    );
  }

  Future<void> _createSchema(Database db) async {
    final batch = db.batch()
      ..execute('''
        CREATE TABLE $transfersTable (
          id TEXT PRIMARY KEY,
          taskId TEXT NOT NULL,
          type TEXT NOT NULL,
          fileName TEXT NOT NULL,
          remoteFileName TEXT,
          localPath TEXT,
          savedPath TEXT,
          url TEXT,
          status TEXT NOT NULL,
          progress REAL NOT NULL DEFAULT 0,
          totalBytes INTEGER,
          transferredBytes INTEGER NOT NULL DEFAULT 0,
          errorKind TEXT,
          errorMessage TEXT,
          canPauseNatively INTEGER NOT NULL DEFAULT 0,
          pauseReason TEXT,
          resumeFromByte INTEGER NOT NULL DEFAULT 0,
          pendingFinalize INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''')
      ..execute(
        'CREATE INDEX idx_transfers_created ON $transfersTable (createdAt DESC)',
      )
      ..execute('''
        CREATE TABLE $cachedFilesTable (
          name TEXT PRIMARY KEY,
          url TEXT NOT NULL,
          sizeBytes INTEGER,
          uploadedAt TEXT,
          position INTEGER NOT NULL,
          cachedAt TEXT NOT NULL
        )
      ''');
    await batch.commit(noResult: true);
  }

  /// Runs each step between the installed version and the current one, so an
  /// app that skipped a release still arrives at the right schema. Without
  /// this an upgrade opens an old table and every write fails on a missing
  /// column — on a terminal that is already in a shop, with history in it.
  Future<void> _upgrade(Database db, int from, int to) async {
    final batch = db.batch();
    if (from < 2) {
      batch
        ..execute('ALTER TABLE $transfersTable ADD COLUMN pauseReason TEXT')
        ..execute(
          'ALTER TABLE $transfersTable '
          'ADD COLUMN resumeFromByte INTEGER NOT NULL DEFAULT 0',
        );
    }
    await batch.commit(noResult: true);
  }

  Future<void> close() async {
    final opened = _opening;
    _opening = null;
    if (opened != null) await (await opened).close();
  }
}
