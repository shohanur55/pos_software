import 'package:sqflite/sqflite.dart';

import '../../models/remote_file_model.dart';
import 'app_database.dart';

/// Caches the server's file list so the Files tab still has content when the
/// terminal is offline.
class RemoteFileDao {
  RemoteFileDao(this._db);

  final AppDatabase _db;

  /// Files in the order they were last received from the server.
  Future<List<RemoteFileModel>> all() async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.cachedFilesTable,
      orderBy: 'position ASC',
    );
    return rows.map(_fromRow).toList();
  }

  /// When the cache was last filled, or `null` if it never was.
  Future<DateTime?> cachedAt() async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.cachedFilesTable,
      columns: ['cachedAt'],
      orderBy: 'cachedAt DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DateTime.tryParse(rows.first['cachedAt']! as String);
  }

  /// Replaces the cache in one transaction, so a failure never leaves a
  /// half-written list behind.
  Future<void> replaceAll(
    List<RemoteFileModel> files,
    DateTime cachedAt,
  ) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.delete(AppDatabase.cachedFilesTable);
      final batch = txn.batch();
      for (final (index, file) in files.indexed) {
        batch.insert(
          AppDatabase.cachedFilesTable,
          _toRow(file, position: index, cachedAt: cachedAt),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> delete(String name) async {
    final db = await _db.database;
    await db.delete(
      AppDatabase.cachedFilesTable,
      where: 'name = ?',
      whereArgs: [name],
    );
  }

  Future<void> clear() async {
    final db = await _db.database;
    await db.delete(AppDatabase.cachedFilesTable);
  }

  static Map<String, Object?> _toRow(
    RemoteFileModel file, {
    required int position,
    required DateTime cachedAt,
  }) => {
    'name': file.name,
    'url': file.url,
    'sizeBytes': file.sizeBytes,
    'uploadedAt': file.uploadedAt?.toIso8601String(),
    'position': position,
    'cachedAt': cachedAt.toIso8601String(),
  };

  static RemoteFileModel _fromRow(Map<String, Object?> row) {
    final uploadedAt = row['uploadedAt'] as String?;
    return RemoteFileModel(
      name: row['name']! as String,
      url: row['url']! as String,
      sizeBytes: row['sizeBytes'] as int?,
      uploadedAt: uploadedAt == null ? null : DateTime.tryParse(uploadedAt),
    );
  }
}
