import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'db_stub.dart'
    if (dart.library.io) 'db_native.dart'
    if (dart.library.js) 'db_web.dart';

class LocalDatabase {
  static final LocalDatabase instance = LocalDatabase._init();
  static Database? _database;
  static String? _currentDbPath;

  LocalDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await openLocalDatabase('labsync_local.db');
    _currentDbPath = _database!.path;
    return _database!;
  }

  String? get currentDbPath => _currentDbPath;

  static String computeChecksum(Map<String, dynamic> data) {
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  Future<bool> checkIntegrity() async {
    try {
      final db = await database;
      await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final result = await db.rawQuery('PRAGMA integrity_check');
      return result.first.values.first == 'ok';
    } catch (_) {
      return false;
    }
  }

  static Future<bool> verifyBackupIntegrity(String dbPath) async {
    try {
      final file = File(dbPath);
      if (!await file.exists()) return false;
      final db = await openDatabase(dbPath, readOnly: true);
      final result = await db.rawQuery('PRAGMA integrity_check');
      await db.close();
      return result.first.values.first == 'ok';
    } catch (_) {
      return false;
    }
  }

  static Future<int> getSchemaVersion(String dbPath) async {
    try {
      final db = await openDatabase(dbPath, readOnly: true);
      final version = await db.getVersion();
      await db.close();
      return version;
    } catch (_) {
      return -1;
    }
  }

  Future<void> moveDatabase(String newDirPath) async {
    if (!await checkIntegrity()) {
      throw Exception('No se puede mover: la base de datos actual esta corrupta');
    }
    final db = await database;
    final oldPath = db.path;

    await db.close();
    _database = null;

    final newPath = p.join(newDirPath, 'labsync_local.db');
    final newDir = Directory(newDirPath);
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    if (await File(newPath).exists()) {
      final backupPath = '$newPath.backup.${DateTime.now().millisecondsSinceEpoch}';
      await File(newPath).copy(backupPath);
    }

    await File(oldPath).copy(newPath);
    await File(oldPath).delete();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('db_path', newDirPath);

    _database = await openDatabase(newPath);
    _currentDbPath = newPath;
  }

  Future<String> exportToDirectory(String baseDir, {String? label}) async {
    if (!await checkIntegrity()) {
      throw Exception('No se puede exportar: base de datos corrupta');
    }
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final exportDir = p.join(baseDir, 'BioLab', 'Backups', dateStr);
    final dir = Directory(exportDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final suffix = label != null ? '_$label' : '';
    final exportPath = p.join(exportDir, 'labsync$suffix.db');
    if (await File(exportPath).exists()) {
      final olderPath = '$exportPath.${now.millisecondsSinceEpoch}';
      await File(exportPath).copy(olderPath);
    }
    await File(db.path).copy(exportPath);
    return exportPath;
  }

  Future<String> exportForVerification(String baseDir) async {
    final db = await database;
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final exportDir = p.join(baseDir, 'BioLab', 'Verificacion', dateStr);
    final dir = Directory(exportDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final entries = await db.query('form_entries', orderBy: 'date ASC');
    final closures = await db.query('day_closures', orderBy: 'date ASC');
    final queue = await db.query('sync_queue', orderBy: 'timestamp ASC');
    final audit = await db.query('audit_log', orderBy: 'timestamp ASC');

    final data = {
      'exported_at': now.toUtc().toIso8601String(),
      'version': 1,
      'entries_count': entries.length,
      'closures_count': closures.length,
      'queue_count': queue.length,
      'audit_count': audit.length,
      'form_entries': entries,
      'day_closures': closures,
      'sync_queue': queue,
      'audit_log': audit,
    };

    final exportPath = p.join(exportDir, 'verificacion.json');
    await File(exportPath).writeAsString(jsonEncode(data));
    return exportPath;
  }

  Future<void> importFromFile(String importFilePath) async {
    if (!await verifyBackupIntegrity(importFilePath)) {
      throw Exception('El archivo de respaldo esta corrupto');
    }
    final version = await getSchemaVersion(importFilePath);
    if (version > 8) {
      throw Exception('El respaldo es de una version mas nueva del sistema');
    }
    if (!await checkIntegrity()) {
      throw Exception('No se puede restaurar: la base de datos actual esta corrupta');
    }
    final db = await database;
    final oldPath = db.path;

    await db.close();
    _database = null;

    final backupPath = '$oldPath.pre_restore.${DateTime.now().millisecondsSinceEpoch}';
    await File(oldPath).copy(backupPath);

    await File(importFilePath).copy(oldPath);

    _database = await openDatabase(oldPath);
    _currentDbPath = oldPath;

    if (!await checkIntegrity()) {
      await File(oldPath).delete();
      await File(backupPath).copy(oldPath);
      _database = await openDatabase(oldPath);
      _currentDbPath = oldPath;
      throw Exception('Error de integridad despues de restaurar. Se revirtio al estado anterior.');
    }
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
    _database = null;
    _currentDbPath = null;
  }
}
