import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

part 'app_database.g.dart';

class Usuarios extends Table {
  TextColumn get id => text().clientDefault(() => '')();
  TextColumn get nombre => text()();
  TextColumn get cargo => text().nullable()();
  TextColumn get cargoOperativo => text().named('cargo_operativo').nullable()();
  TextColumn get area => text().withDefault(const Constant('Cultivo Celular'))();
  TextColumn get supervisor => text().withDefault(const Constant(''))();
  TextColumn get firma => text().withDefault(const Constant(''))();
  TextColumn get rol => text()();
  TextColumn get pinHash => text().named('pin_hash').nullable()();
  TextColumn get passHash => text().named('pass_hash').nullable()();
  BoolColumn get activo => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().named('created_at').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class FormEntries extends Table {
  TextColumn get id => text().clientDefault(() => '')();
  TextColumn get module => text()();
  TextColumn get date => text()();
  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get deviceId => text().named('device_id').nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get dataJson => text().named('data_json')();
  TextColumn get checksum => text().nullable()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at').nullable()();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<TableIndex> get indexes => [
    TableIndex('idx_form_entries_user_id', [userId]),
    TableIndex('idx_form_entries_date', [date]),
  ];
}

class DayClosures extends Table {
  TextColumn get id => text().clientDefault(() => '')();
  DateTimeColumn get date => dateTime().unique()();
  TextColumn get status => text()();
  TextColumn get closedBy => text().named('closed_by').nullable()();
  DateTimeColumn get closedAt => dateTime().named('closed_at').nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get reopenLogJson => text().named('reopen_log_json').withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<TableIndex> get indexes => [
    TableIndex('idx_day_closures_date', [date]),
  ];
}

class MonthClosures extends Table {
  TextColumn get id => text().clientDefault(() => '')();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  TextColumn get status => text()();
  TextColumn get closedBy => text().named('closed_by').nullable()();
  DateTimeColumn get closedAt => dateTime().named('closed_at').nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get reopenLogJson => text().named('reopen_log_json').withDefault(const Constant('[]'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<TableIndex> get indexes => [
    TableIndex('idx_month_closures_year_month', [year, month], isUnique: true),
  ];
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get action => text()();
  TextColumn get entity => text()();
  TextColumn get entityId => text().named('entity_id')();
  TextColumn get dataJson => text().named('data_json')();
  TextColumn get timestamp => text()();

  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  List<TableIndex> get indexes => [
    TableIndex('idx_sync_queue_timestamp', [timestamp]),
  ];
}

class AuditLogs extends Table {
  TextColumn get id => text().clientDefault(() => '')();
  TextColumn get action => text()();
  TextColumn get userId => text().named('user_id').nullable()();
  TextColumn get deviceId => text().named('device_id').nullable()();
  DateTimeColumn get timestamp => dateTime().nullable()();
  TextColumn get detailsJson => text().named('details_json').nullable()();
  TextColumn get entityId => text().named('entity_id').nullable()();
  TextColumn get changedFieldsJson => text().named('changed_fields_json').nullable()();
  TextColumn get checksum => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<TableIndex> get indexes => [
    TableIndex('idx_audit_logs_user_id', [userId]),
    TableIndex('idx_audit_logs_timestamp', [timestamp]),
  ];
}

class Templates extends Table {
  TextColumn get id => text().clientDefault(() => '')();
  TextColumn get name => text()();
  TextColumn get module => text().nullable()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get structureJson => text().named('structure_json')();
  DateTimeColumn get createdAt => dateTime().named('created_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Usuarios,
    FormEntries,
    DayClosures,
    MonthClosures,
    SyncQueue,
    AuditLogs,
    Templates,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.recreateAll();
      }
    },
  );

  Future<bool> checkIntegrity() async {
    try {
      final result = await customSelect('PRAGMA integrity_check').get();
      return result.first.data.values.first == 'ok';
    } catch (_) {
      return false;
    }
  }

  static String computeChecksum(Map<String, dynamic> data) {
    return sha256.convert(utf8.encode(jsonEncode(data))).toString();
  }

  Future<String> exportToDirectory(String baseDir, {String? label}) async {
    if (!await checkIntegrity()) {
      throw Exception('No se puede exportar: base de datos corrupta');
    }

    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final exportDir = Directory('${baseDir}/BioLab/Backups/$dateStr');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }

    final suffix = label != null ? '_$label' : '';
    final dbPath = '${exportDir.path}/labsync$suffix.db';

    final dbFile = File(dbPath);
    if (await dbFile.exists()) {
      await dbFile.copy('$dbPath.${now.millisecondsSinceEpoch}');
    }

    final sourceFile = File(p.join(
      (await getApplicationDocumentsDirectory()).path,
      'biolab_labsync.db',
    ));
    if (await sourceFile.exists()) {
      await sourceFile.copy(dbPath);
    }
    return dbPath;
  }

  Future<void> queueSyncAction({
    required String action,
    required String entity,
    required String entityId,
    required Map<String, dynamic> data,
  }) async {
    await into(syncQueue).insert(SyncQueueCompanion.insert(
      action: action,
      entity: entity,
      entityId: entityId,
      dataJson: jsonEncode(data),
      timestamp: DateTime.now().toUtc().toIso8601String(),
    ));
  }

  Future<List> getSyncQueue() async {
    return await select(syncQueue).get();
  }

  Future<void> deleteQueueItem(int id) async {
    await (delete(syncQueue)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearSyncQueue() async {
    await delete(syncQueue).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbFileName = 'biolab_labsync.db';
    final file = File(p.join(docsDir.path, dbFileName));

    final prefs = await SharedPreferences.getInstance();
    final customPath = prefs.getString('db_path');
    if (customPath != null) {
      final customDir = Directory(customPath);
      if (await customDir.exists()) {
        return NativeDatabase(File(p.join(customPath, dbFileName)));
      }
    }

    return NativeDatabase(file);
  });
}
