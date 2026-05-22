import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

bool _sqfliteInitialized = false;

void ensureSqfliteInit() {
  if (!_sqfliteInitialized && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _sqfliteInitialized = true;
  }
}

Future<Database> openLocalDatabase(String filePath) async {
  ensureSqfliteInit();

  final appDir = await getApplicationSupportDirectory();
  final dbPath = join(appDir.path, filePath);

  return openDatabase(
    dbPath,
    version: 4,
    onCreate: (db, version) async {
      await db.execute('''
        CREATE TABLE form_entries (
          id TEXT PRIMARY KEY,
          module TEXT NOT NULL,
          sub_module TEXT,
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

      await db.execute('''
        CREATE TABLE IF NOT EXISTS day_module_status (
          id TEXT PRIMARY KEY,
          date TEXT NOT NULL,
          module TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'pendiente',
          updated_by TEXT,
          updated_at TEXT NOT NULL,
          notes TEXT,
          UNIQUE(date, module)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS month_closures (
          id TEXT PRIMARY KEY,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          status TEXT NOT NULL,
          closed_by TEXT NOT NULL,
          closed_at TEXT NOT NULL,
          notes TEXT,
          days_total INTEGER DEFAULT 30,
          days_closed INTEGER DEFAULT 0,
          reopen_log_json TEXT NOT NULL DEFAULT '[]',
          UNIQUE(year, month)
        )
      ''');
    },
    onUpgrade: (db, oldVersion, newVersion) async {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE form_entries ADD COLUMN sub_module TEXT');
      }
      if (oldVersion < 3) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS day_module_status (
            id TEXT PRIMARY KEY,
            date TEXT NOT NULL,
            module TEXT NOT NULL,
            status TEXT NOT NULL DEFAULT 'pendiente',
            updated_by TEXT,
            updated_at TEXT NOT NULL,
            notes TEXT,
            UNIQUE(date, module)
          )
        ''');
      }
      if (oldVersion < 4) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS month_closures (
            id TEXT PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            status TEXT NOT NULL,
            closed_by TEXT NOT NULL,
            closed_at TEXT NOT NULL,
            notes TEXT,
            days_total INTEGER DEFAULT 30,
            days_closed INTEGER DEFAULT 0,
            reopen_log_json TEXT NOT NULL DEFAULT '[]',
            UNIQUE(year, month)
          )
        ''');
      }
    },
  );
}
