import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

Future<Database> openLocalDatabase(String filePath) async {
  final appDir = await getApplicationSupportDirectory();
  final dbPath = join(appDir.path, filePath);

  return openDatabase(
    dbPath,
    version: 1,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE form_entries (
          id TEXT PRIMARY KEY,
          module TEXT NOT NULL,
          date TEXT NOT NULL,
          user_id TEXT NOT NULL,
          device_id TEXT NOT NULL,
          version INTEGER NOT NULL,
          data_json TEXT NOT NULL,
          status TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE day_closures (
          id TEXT PRIMARY KEY,
          date TEXT UNIQUE NOT NULL,
          status TEXT NOT NULL,
          closed_by TEXT NOT NULL,
          closed_at TEXT NOT NULL,
          notes TEXT,
          reopen_log_json TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE audit_log (
          id TEXT PRIMARY KEY,
          action TEXT NOT NULL,
          user_id TEXT,
          device_id TEXT,
          timestamp TEXT NOT NULL,
          details_json TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE sync_queue (
          id TEXT PRIMARY KEY,
          action TEXT NOT NULL,
          entity TEXT NOT NULL,
          entity_id TEXT NOT NULL,
          data_json TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    },
  );
}
