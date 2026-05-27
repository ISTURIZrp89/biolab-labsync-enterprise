import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String dbPath;
  try {
    final prefs = await SharedPreferences.getInstance();
    final customDir = prefs.getString('db_path');
    if (customDir != null && customDir.isNotEmpty) {
      final dir = Directory(customDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      dbPath = join(customDir, filePath);
    } else {
      final appDir = await getApplicationSupportDirectory();
      dbPath = join(appDir.path, filePath);
    }
  } catch (e) {
    final appDir = await getApplicationSupportDirectory();
    dbPath = join(appDir.path, filePath);
    debugPrint('openLocalDatabase: fallback to default path: $e');
  }
  debugPrint('openLocalDatabase path: $dbPath');

  return openDatabase(
    dbPath,
    version: 9,
    onConfigure: (db) async {
      await db.execute('PRAGMA journal_mode=WAL');
      await db.execute('PRAGMA synchronous=NORMAL');
      await db.execute('PRAGMA foreign_keys=ON');
    },
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
          checksum TEXT NOT NULL DEFAULT '',
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

      await db.execute('''
        CREATE TABLE IF NOT EXISTS report_personnel (
          id TEXT PRIMARY KEY,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          user_id TEXT NOT NULL,
          nombre TEXT NOT NULL,
          cargo TEXT NOT NULL DEFAULT '',
          area TEXT NOT NULL DEFAULT '',
          activo INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          UNIQUE(year, month, user_id)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS report_covers (
          id TEXT PRIMARY KEY,
          year INTEGER NOT NULL,
          month INTEGER NOT NULL,
          title TEXT NOT NULL DEFAULT '',
          subtitle TEXT NOT NULL DEFAULT '',
          notes TEXT NOT NULL DEFAULT '',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          UNIQUE(year, month)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          cargo TEXT NOT NULL DEFAULT '',
          cargo_operativo TEXT NOT NULL DEFAULT '',
          rol TEXT NOT NULL,
          area TEXT NOT NULL DEFAULT '',
          supervisor TEXT NOT NULL DEFAULT '',
          firma TEXT NOT NULL DEFAULT '',
          pin TEXT NOT NULL DEFAULT '',
          permisos TEXT NOT NULL DEFAULT 'todos',
          activo INTEGER NOT NULL DEFAULT 1,
          pin_change_required INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
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
      if (oldVersion < 5) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS form_entry_drafts (
            id TEXT PRIMARY KEY,
            module TEXT NOT NULL,
            section_key TEXT,
            date TEXT NOT NULL,
            data_json TEXT NOT NULL,
            user_id TEXT NOT NULL,
            saved_at TEXT NOT NULL
          )
        ''');
        try { await db.execute('ALTER TABLE day_module_status ADD COLUMN entry_count INTEGER DEFAULT 0'); } catch (_) {}
      }
      if (oldVersion < 6) {
        // Granular field-level audit trail
        try { await db.execute('ALTER TABLE audit_log ADD COLUMN entity_id TEXT'); } catch (_) {}
        try { await db.execute('ALTER TABLE audit_log ADD COLUMN changed_fields_json TEXT'); } catch (_) {}
        await db.execute('''
          CREATE TABLE IF NOT EXISTS company_info (
            id TEXT PRIMARY KEY DEFAULT 'default',
            company_name TEXT NOT NULL DEFAULT '',
            logo_base64 TEXT NOT NULL DEFAULT '',
            personnel_json TEXT NOT NULL DEFAULT '[]',
            report_output_path TEXT NOT NULL DEFAULT ''
          )
        ''');
        await db.insert('company_info', {
          'id': 'default',
          'company_name': '',
          'logo_base64': '',
          'personnel_json': '[]',
          'report_output_path': '',
        });
      }
      if (oldVersion < 7) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS report_personnel (
            id TEXT PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            user_id TEXT NOT NULL,
            nombre TEXT NOT NULL,
            cargo TEXT NOT NULL DEFAULT '',
            area TEXT NOT NULL DEFAULT '',
            activo INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            UNIQUE(year, month, user_id)
          )
        ''');
        await db.execute('''
          CREATE TABLE IF NOT EXISTS report_covers (
            id TEXT PRIMARY KEY,
            year INTEGER NOT NULL,
            month INTEGER NOT NULL,
            title TEXT NOT NULL DEFAULT '',
            subtitle TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            UNIQUE(year, month)
          )
        ''');
      }
      if (oldVersion < 8) {
        try { await db.execute('ALTER TABLE form_entries ADD COLUMN checksum TEXT NOT NULL DEFAULT \'\''); } catch (_) {}
      }
      if (oldVersion < 9) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id TEXT PRIMARY KEY,
            nombre TEXT NOT NULL,
            cargo TEXT NOT NULL DEFAULT '',
            cargo_operativo TEXT NOT NULL DEFAULT '',
            rol TEXT NOT NULL,
            area TEXT NOT NULL DEFAULT '',
            supervisor TEXT NOT NULL DEFAULT '',
            firma TEXT NOT NULL DEFAULT '',
            pin TEXT NOT NULL DEFAULT '',
            permisos TEXT NOT NULL DEFAULT 'todos',
            activo INTEGER NOT NULL DEFAULT 1,
            pin_change_required INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
        try {
          final prefs = await SharedPreferences.getInstance();
          final raw = prefs.getString('users_list');
          if (raw != null && raw.isNotEmpty) {
            final List existing = jsonDecode(raw);
            final now = DateTime.now().toUtc().toIso8601String();
            for (final u in existing) {
              final id = u['id']?.toString() ?? '';
              if (id.isEmpty) continue;
              final count = Sqflite.firstIntValue(await db.rawQuery(
                'SELECT COUNT(*) FROM users WHERE id = ?', [id],
              )) ?? 0;
              if (count == 0) {
                await db.insert('users', {
                  'id': id,
                  'nombre': u['nombre'] ?? '',
                  'cargo': u['cargo'] ?? '',
                  'cargo_operativo': u['cargo_operativo'] ?? u['rol'] ?? '',
                  'rol': u['rol'] ?? 'Laboratorio',
                  'area': u['area'] ?? '',
                  'supervisor': u['supervisor'] ?? '',
                  'firma': u['firma'] ?? '',
                  'pin': u['pin'] ?? '',
                  'permisos': u['permisos'] ?? 'todos',
                  'activo': 1,
                  'pin_change_required': 0,
                  'created_at': now,
                  'updated_at': now,
                });
              }
            }
          }
        } catch (e) {
          debugPrint('db_native: migration v9 users copy error: $e');
        }
      }
    },
  );
}
