import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';
import '../domain/entities/form_entry.dart';

class ModuleDayStatus {
  final String id;
  final String date;
  final String module;
  String status;
  String? updatedBy;
  String updatedAt;
  String? notes;
  int entryCount;

  ModuleDayStatus({
    required this.id,
    required this.date,
    required this.module,
    this.status = 'pendiente',
    this.updatedBy,
    String? updatedAt,
    this.notes,
    this.entryCount = 0,
  }) : updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'module': module,
    'status': status,
    'updated_by': updatedBy,
    'updated_at': updatedAt,
    'notes': notes,
    'entry_count': entryCount,
  };

  static String statusLabel(String s) {
    switch (s) {
      case 'borrador': return 'Borrador';
      case 'pendiente': return 'Pendiente';
      case 'completado': return 'Completado';
      case 'revisado': return 'Revisado';
      case 'corregido': return 'Corregido';
      case 'cerrado': return 'Cerrado';
      case 'reabierto': return 'Reabierto';
      case 'justificado': return 'Justificado';
      case 'cancelado': return 'Cancelado';
      default: return s;
    }
  }
}

class DashboardService extends ChangeNotifier {
  final LocalDatabase _localDb;
  Map<String, Map<String, ModuleDayStatus>> _statusCache = {};
  bool _disposed = false;

  DashboardService({LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  Map<String, ModuleDayStatus> getStatusesForDate(String date) =>
      _statusCache[date] ?? {};

  Future<void> loadStatusesForDate(String date) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'day_module_status',
        where: 'date = ?',
        whereArgs: [date],
      );

      final map = <String, ModuleDayStatus>{};
      for (final row in rows) {
        final status = ModuleDayStatus(
          id: row['id'] as String,
          date: row['date'] as String,
          module: row['module'] as String,
          status: row['status'] as String? ?? 'pendiente',
          updatedBy: row['updated_by'] as String?,
          updatedAt: row['updated_at'] as String?,
          notes: row['notes'] as String?,
          entryCount: row['entry_count'] as int? ?? 0,
        );
        map[status.module] = status;
      }

      final entryRows = await db.query(
        'form_entries',
        columns: ['module', 'date', 'status'],
        where: 'date = ?',
        whereArgs: [date],
      );

      for (final er in entryRows) {
        final mod = er['module'] as String? ?? '';
        final st = er['status'] as String? ?? 'completado';
        if (!map.containsKey(mod)) {
          map[mod] = ModuleDayStatus(
            id: 'dms-${date}-$mod',
            date: date,
            module: mod,
            status: st,
            entryCount: 1,
          );
        } else {
          map[mod]!.entryCount = (map[mod]!.entryCount) + 1;
          if (map[mod]!.status == 'pendiente' || map[mod]!.status == 'borrador') {
            map[mod]!.status = st;
          }
        }
      }

      _statusCache[date] = map;
      _safeNotify();
    } catch (e) {
      debugPrint('DashboardService: load error: $e');
    }
  }

  Future<void> setStatus({
    required String date,
    required String module,
    required String status,
    String? updatedBy,
    String? notes,
  }) async {
    try {
      final db = await _localDb.database;
      final now = DateTime.now().toIso8601String();
      final id = 'dms-${date}-$module';

      await db.insert('day_module_status', {
        'id': id,
        'date': date,
        'module': module,
        'status': status,
        'updated_by': updatedBy,
        'updated_at': now,
        'notes': notes,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      _statusCache[date] ??= {};
      _statusCache[date]![module] = ModuleDayStatus(
        id: id,
        date: date,
        module: module,
        status: status,
        updatedBy: updatedBy,
        updatedAt: now,
        notes: notes,
      );

      if (status == 'cerrado') {
        await db.update(
          'form_entries',
          {'status': 'cerrado'},
          where: 'module = ? AND date = ? AND status NOT IN (?, ?)',
          whereArgs: [module, date, 'cancelado', 'justificado'],
        );
      }

      _safeNotify();
    } catch (e) {
      debugPrint('DashboardService: setStatus error: $e');
    }
  }

  String getStatusForModule(String date, String module) {
    return _statusCache[date]?[module]?.status ?? 'pendiente';
  }

  Future<Map<String, int>> getStatusCountsForDate(String date) async {
    final counts = <String, int>{};
    try {
      final db = await _localDb.database;
      final rows = await db.query(
        'day_module_status',
        where: 'date = ?',
        whereArgs: [date],
      );
      for (final row in rows) {
        final s = row['status'] as String? ?? 'pendiente';
        counts[s] = (counts[s] ?? 0) + 1;
      }
    } catch (_) {}
    return counts;
  }

  int getCompletedCount(String date) {
    final map = _statusCache[date] ?? {};
    return map.values.where((s) =>
      s.status == 'completado' || s.status == 'revisado' || s.status == 'cerrado').length;
  }

  int getPendingCount(String date) {
    final map = _statusCache[date] ?? {};
    return map.values.where((s) =>
      s.status == 'pendiente' || s.status == 'borrador').length;
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
