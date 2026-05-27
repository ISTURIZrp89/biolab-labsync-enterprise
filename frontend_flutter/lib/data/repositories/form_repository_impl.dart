import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/form_entry.dart';
import '../../domain/repositories/form_repository.dart';
import '../db.dart';

class DuplicateEntryException implements Exception {
  final String message;
  DuplicateEntryException(this.message);
  @override
  String toString() => message;
}

class FormRepositoryImpl implements FormRepository {
  final LocalDatabase _db = LocalDatabase.instance;
  final _uuid = const Uuid();

  @override
  Future<List<FormEntry>> getEntries(String module, String date) async {
    final db = await _db.database;
    final rows = await db.query(
      'form_entries',
      where: 'module = ? AND date = ?',
      whereArgs: [module, date],
      orderBy: 'created_at DESC',
    );
    return rows.map((row) => _rowToEntry(row)).toList();
  }

  @override
  Future<List<FormEntry>> getEntriesByModule(String module) async {
    final db = await _db.database;
    final rows = await db.query(
      'form_entries',
      where: 'module = ?',
      whereArgs: [module],
      orderBy: 'date DESC',
    );
    return rows.map((row) => _rowToEntry(row)).toList();
  }

  Future<List<FormEntry>> getEntriesByModuleAndSubModule(String module, String subModule) async {
    final db = await _db.database;
    final rows = await db.query(
      'form_entries',
      where: 'module = ? AND sub_module = ?',
      whereArgs: [module, subModule],
      orderBy: 'date DESC',
    );
    return rows.map((row) => _rowToEntry(row)).toList();
  }

  @override
  Future<FormEntry?> getEntryById(String id) async {
    final db = await _db.database;
    final rows = await db.query(
      'form_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _rowToEntry(rows.first);
  }

  FormEntry _rowToEntry(Map<String, dynamic> row) {
    return FormEntry(
      id: row['id'] as String,
      module: row['module'] as String,
      subModule: row['sub_module'] as String?,
      date: row['date'] as String,
      userId: row['user_id'] as String,
      deviceId: row['device_id'] as String,
      version: row['version'] as int,
      data: jsonDecode(row['data_json'] as String),
      status: row['status'] as String,
      createdAt: row['created_at'] as String,
      updatedAt: row['updated_at'] as String,
    );
  }

  @override
  Future<void> saveEntry(FormEntry entry) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      final checksum = LocalDatabase.computeChecksum(entry.data);

      final existing = await txn.query('form_entries',
        where: 'id = ?', whereArgs: [entry.id]);

      if (existing.isNotEmpty) {
        final currentVersion = existing.first['version'] as int;
        if (entry.version <= currentVersion) {
          throw Exception(
            'Conflicto de version: registro #$currentVersion, '
            'intentaste guardar #${entry.version}'
          );
        }
      }

      final dupes = await txn.query('form_entries',
        where: 'date = ? AND module = ? AND user_id = ? AND data_json = ?',
        whereArgs: [entry.date, entry.module, entry.userId, jsonEncode(entry.data)]);

      if (dupes.isNotEmpty && dupes.first['id'] != entry.id) {
        throw DuplicateEntryException(
          'Ya existe un registro identico para ${entry.date} en ${entry.module}'
        );
      }

      await txn.insert('form_entries', {
        'id': entry.id,
        'module': entry.module,
        'sub_module': entry.subModule,
        'date': entry.date,
        'user_id': entry.userId,
        'device_id': entry.deviceId,
        'version': entry.version,
        'data_json': jsonEncode(entry.data),
        'checksum': checksum,
        'status': entry.status,
        'created_at': entry.createdAt,
        'updated_at': entry.updatedAt,
      }, conflictAlgorithm: ConflictAlgorithm.fail);
    });

    await _db.queueSyncAction(
      action: entry.version > 1 ? 'UPDATE' : 'CREATE',
      entity: 'form_entries',
      entityId: entry.id,
      data: entry.toJson(),
    );
  }

  Future<FormEntry> createEntry({
    required String module,
    String? subModule,
    required String date,
    required String userId,
    required String deviceId,
    required Map<String, dynamic> data,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final entry = FormEntry(
      id: _uuid.v4(),
      module: module,
      subModule: subModule,
      date: date,
      userId: userId,
      deviceId: deviceId,
      version: 1,
      data: data,
      status: 'saved',
      createdAt: now,
      updatedAt: now,
    );
    await saveEntry(entry);
    return entry;
  }

  @override
  Future<void> deleteEntry(String id) async {
    final db = await _db.database;
    final entry = await getEntryById(id);
    if (entry != null) {
      await _db.queueSyncAction(
        action: 'DELETE',
        entity: 'form_entries',
        entityId: id,
        data: entry.toJson(),
      );
    }
    await db.delete('form_entries', where: 'id = ?', whereArgs: [id]);
  }
}
