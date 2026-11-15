import 'package:sqflite/sqflite.dart';

import '../../../core/utils/app_logger.dart';
import '../../models/transfer_model.dart';
import 'app_database.dart';

/// Reads and writes transfer rows.
///
/// Progress ticks are not persisted; only status changes are, so a busy
/// transfer does not hammer the disk.
class TransferDao {
  TransferDao(this._db);

  final AppDatabase _db;

  Future<List<TransferModel>> all() async {
    final db = await _db.database;
    final rows = await db.query(
      AppDatabase.transfersTable,
      orderBy: 'createdAt DESC',
    );
    final transfers = <TransferModel>[];
    for (final row in rows) {
      try {
        transfers.add(_fromRow(row));
      } on Object catch (error) {
        // One unreadable row must not take the whole history down with it.
        logger.w('Skipping unreadable transfer row: $error');
      }
    }
    return transfers;
  }

  Future<void> upsert(TransferModel transfer) async {
    final db = await _db.database;
    await db.insert(
      AppDatabase.transfersTable,
      _toRow(transfer),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteByIds(Iterable<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _db.database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      AppDatabase.transfersTable,
      where: 'id IN ($placeholders)',
      whereArgs: ids.toList(),
    );
  }

  Future<void> deleteAll() async {
    final db = await _db.database;
    await db.delete(AppDatabase.transfersTable);
  }

  /// The JSON shape is already flat, so it doubles as the row shape. Only the
  /// booleans need converting, because SQLite has no boolean type.
  static Map<String, Object?> _toRow(TransferModel transfer) {
    final row = Map<String, Object?>.of(transfer.toJson());
    for (final key in const ['canPauseNatively', 'pendingFinalize']) {
      row[key] = (row[key] as bool? ?? false) ? 1 : 0;
    }
    return row;
  }

  static TransferModel _fromRow(Map<String, Object?> row) {
    final json = Map<String, Object?>.of(row);
    for (final key in const ['canPauseNatively', 'pendingFinalize']) {
      json[key] = (json[key] as int? ?? 0) == 1;
    }
    return TransferModel.fromJson(json);
  }
}
