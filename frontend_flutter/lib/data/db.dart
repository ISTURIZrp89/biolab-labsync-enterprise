import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'db_stub.dart'
    if (dart.library.io) 'db_native.dart'
    if (dart.library.js) 'db_web.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openLocalDatabase('labsync_local.db');
    return _database!;
  }

  Future<void> queueSyncAction({
    required String action,
    required String entity,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    final db = await database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert('sync_queue', {
      'id': 'sq-${DateTime.now().microsecondsSinceEpoch}',
      'action': action,
      'entity': entity,
      'entity_id': entityId,
      'data_json': jsonEncode(data),
      'timestamp': now,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncQueue() async {
    final db = await database;
    return await db.query('sync_queue', orderBy: 'timestamp ASC');
  }

  Future<void> deleteQueueItem(String id) async {
    final db = await database;
    await db.delete('sync_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearSyncQueue() async {
    final db = await database;
    await db.delete('sync_queue');
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
