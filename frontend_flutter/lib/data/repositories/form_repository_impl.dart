import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/form_entry.dart';
import '../../domain/repositories/form_repository.dart';
import '../db.dart';

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
    return rows.map((row) {
      return FormEntry(
        id: row['id'] as String,
        module: row['module'] as String,
        date: row['date'] as String,
        userId: row['user_id'] as String,
        deviceId: row['device_id'] as String,
        version: row['version'] as int,
        data: jsonDecode(row['data_json'] as String),
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
      );
    }).toList();
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
    return rows.map((row) {
      return FormEntry(
        id: row['id'] as String,
        module: row['module'] as String,
        date: row['date'] as String,
        userId: row['user_id'] as String,
        deviceId: row['device_id'] as String,
        version: row['version'] as int,
        data: jsonDecode(row['data_json'] as String),
        status: row['status'] as String,
        createdAt: row['created_at'] as String,
        updatedAt: row['updated_at'] as String,
      );
    }).toList();
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
    final row = rows.first;
    return FormEntry(
      id: row['id'] as String,
      module: row['module'] as String,
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
    await db.insert(
      'form_entries',
      {
        'id': entry.id,
        'module': entry.module,
        'date': entry.date,
        'user_id': entry.userId,
        'device_id': entry.deviceId,
        'version': entry.version,
        'data_json': jsonEncode(entry.data),
        'status': entry.status,
        'created_at': entry.createdAt,
        'updated_at': entry.updatedAt,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _db.queueSyncAction(
      action: entry.version > 1 ? 'UPDATE' : 'CREATE',
      entity: 'form_entries',
      entityId: entry.id,
      data: entry.toJson(),
    );
  }

  Future<FormEntry> createEntry({
    required String module,
    required String date,
    required String userId,
    required String deviceId,
    required Map<String, dynamic> data,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final entry = FormEntry(
      id: _uuid.v4(),
      module: module,
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
