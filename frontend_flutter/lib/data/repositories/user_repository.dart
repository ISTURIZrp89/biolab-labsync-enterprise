import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db.dart';

class UserRepository {
  final LocalDatabase _localDb;

  UserRepository({LocalDatabase? localDb}) : _localDb = localDb ?? LocalDatabase.instance;

  Future<List<Map<String, String>>> getAllUsers() async {
    try {
      final db = await _localDb.database;
      final rows = await db.query('users', orderBy: 'nombre ASC');
      if (rows.isNotEmpty) {
        return rows.map((r) => Map<String, String>.from(
          r.map((k, v) => MapEntry(k, v?.toString() ?? '')),
        )).toList();
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        return list.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }
    return [];
  }

  Future<void> saveAllUsers(List<Map<String, String>> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users_list', jsonEncode(users));

    try {
      final db = await _localDb.database;
      final now = DateTime.now().toUtc().toIso8601String();
      final existingIds = (await db.query('users'))
          .map((r) => r['id']?.toString() ?? '').toSet();
      final newIds = users.map((u) => u['id'] ?? '').toSet();

      for (final removed in existingIds.where((id) => id.isNotEmpty && !newIds.contains(id))) {
        await db.delete('users', where: 'id = ?', whereArgs: [removed]);
      }

      for (final u in users) {
        final id = u['id'] ?? '';
        if (id.isEmpty) continue;
        final row = {
          'id': id,
          'nombre': u['nombre'] ?? '',
          'cargo': u['cargo'] ?? '',
          'cargo_operativo': u['cargo_operativo'] ?? u['rol'] ?? '',
          'rol': u['rol'] ?? 'Laboratorio',
          'area': u['area'] ?? '',
          'supervisor': u['supervisor'] ?? '',
          'firma': u['firma'] ?? u['nombre'] ?? '',
          'pin': u['pin'] ?? '',
          'permisos': u['permisos'] ?? 'todos',
          'activo': 1,
          'updated_at': now,
        };
        if (existingIds.contains(id)) {
          await db.update('users', row, where: 'id = ?', whereArgs: [id]);
        } else {
          row['pin_change_required'] = 1;
          row['created_at'] = now;
          await db.insert('users', row, conflictAlgorithm: null);
        }
      }
    } catch (e) {
      debugPrint('UserRepository.saveAllUsers SQLite error: $e');
    }
  }

  Future<Map<String, String>?> findById(String id) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
      if (rows.isNotEmpty) {
        return Map<String, String>.from(
          rows.first.map((k, v) => MapEntry(k, v?.toString() ?? '')),
        );
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final u in list) {
          if (u['id']?.toString() == id) {
            return Map<String, String>.from(u as Map);
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<void> deleteUser(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        list.removeWhere((u) => u['id']?.toString() == id);
        await prefs.setString('users_list', jsonEncode(list));
      } catch (_) {}
    }

    try {
      final db = await _localDb.database;
      await db.delete('users', where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  Future<void> markPinChanged(String id) async {
    try {
      final db = await _localDb.database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.update('users', {
        'pin_change_required': 0,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  Future<bool> isPinChangeRequired(String id) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query('users',
        where: 'id = ? AND pin_change_required = 1',
        whereArgs: [id],
      );
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String id, String newPin) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        for (final u in list) {
          if (u['id']?.toString() == id) {
            u['pin'] = newPin;
            break;
          }
        }
        await prefs.setString('users_list', jsonEncode(list));
      } catch (_) {}
    }

    try {
      final db = await _localDb.database;
      final now = DateTime.now().toUtc().toIso8601String();
      await db.update('users', {
        'pin': newPin,
        'pin_change_required': 0,
        'updated_at': now,
      }, where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }
}
