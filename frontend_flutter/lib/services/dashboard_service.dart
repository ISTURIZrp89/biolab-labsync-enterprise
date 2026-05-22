import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db.dart';

class ModuleDayStatus {
  final String id;
  final String date;
  final String module;
  String status;
  String? updatedBy;
  String updatedAt;
  String? notes;

  ModuleDayStatus({
    required this.id,
    required this.date,
    required this.module,
    this.status = 'pendiente',
    this.updatedBy,
    String? updatedAt,
    this.notes,
  }) : updatedAt = updatedAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'module': module,
    'status': status,
    'updated_by': updatedBy,
    'updated_at': updatedAt,
    'notes': notes,
  };

  static const statuses = ['pendiente', 'completado', 'incidencia', 'no_laborado', 'justificado'];

  static String statusLabel(String s) {
    switch (s) {
      case 'completado': return 'Completado';
      case 'pendiente': return 'Pendiente';
      case 'incidencia': return 'Incidencia';
      case 'no_laborado': return 'No laborado';
      case 'justificado': return 'Justificado';
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
        );
        map[status.module] = status;
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
    return map.values.where((s) => s.status == 'completado').length;
  }

  int getPendingCount(String date) {
    final map = _statusCache[date] ?? {};
    return map.values.where((s) => s.status == 'pendiente').length;
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
