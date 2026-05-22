import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../data/db.dart';
import '../domain/entities/user.dart';

class ClosureInfo {
  final String id;
  final String date;
  String status;
  final String closedBy;
  final String closedAt;
  String? notes;
  List<Map<String, dynamic>> reopenLog;

  ClosureInfo({
    required this.id,
    required this.date,
    this.status = 'CERRADO',
    required this.closedBy,
    String? closedAt,
    this.notes,
    List<Map<String, dynamic>>? reopenLog,
  })  : closedAt = closedAt ?? DateTime.now().toUtc().toIso8601String(),
        reopenLog = reopenLog ?? [];

  bool get isClosed => status == 'CERRADO' || status == 'CERRADO_OBSERVACION';
  bool get isReopened => reopenLog.isNotEmpty && reopenLog.last['type'] == 'reopen';

  factory ClosureInfo.fromMap(Map<String, dynamic> map) {
    List<Map<String, dynamic>> log = [];
    try {
      final raw = map['reopen_log_json'] as String? ?? '[]';
      log = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
    return ClosureInfo(
      id: map['id'] as String,
      date: map['date'] as String,
      status: map['status'] as String? ?? 'CERRADO',
      closedBy: map['closed_by'] as String? ?? '',
      closedAt: map['closed_at'] as String?,
      notes: map['notes'] as String?,
      reopenLog: log,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'date': date,
    'status': status,
    'closed_by': closedBy,
    'closed_at': closedAt,
    'notes': notes,
    'reopen_log_json': jsonEncode(reopenLog),
  };
}

class MonthlyClosureInfo {
  final int year;
  final int month;
  String status;
  final String closedBy;
  final String closedAt;
  String? notes;
  int daysOpen;
  int daysClosed;
  List<Map<String, dynamic>> reopenLog;

  MonthlyClosureInfo({
    required this.year,
    required this.month,
    this.status = 'ABIERTO',
    required this.closedBy,
    String? closedAt,
    this.notes,
    this.daysOpen = 0,
    this.daysClosed = 0,
    List<Map<String, dynamic>>? reopenLog,
  })  : closedAt = closedAt ?? DateTime.now().toUtc().toIso8601String(),
        reopenLog = reopenLog ?? [];

  bool get isClosed => status == 'CERRADO';
  String get monthKey => '$year-${month.toString().padLeft(2, "0")}';
}

class ClosureService extends ChangeNotifier {
  final LocalDatabase _localDb;
  final _uuid = const Uuid();
  bool _disposed = false;

  ClosureService({LocalDatabase? localDb})
      : _localDb = localDb ?? LocalDatabase.instance;

  Map<String, ClosureInfo> _dailyClosures = {};
  Map<String, MonthlyClosureInfo> _monthlyClosures = {};

  Map<String, ClosureInfo> get dailyClosures => _dailyClosures;
  Map<String, MonthlyClosureInfo> get monthlyClosures => _monthlyClosures;

  ClosureInfo? getDayClosure(String date) => _dailyClosures[date];
  MonthlyClosureInfo? getMonthClosure(int year, int month) => _monthlyClosures['$year-${month.toString().padLeft(2, "0")}'];

  bool isDayClosed(String date) {
    final c = _dailyClosures[date];
    return c != null && c.isClosed;
  }

  bool isDayReopened(String date) {
    final c = _dailyClosures[date];
    return c != null && c.isReopened;
  }

  Future<void> loadDailyClosures(String date) async {
    try {
      final db = await _localDb.database;
      final rows = await db.query('day_closures', where: 'date = ?', whereArgs: [date]);
      if (rows.isNotEmpty) {
        _dailyClosures[date] = ClosureInfo.fromMap(rows.first);
      }
      _safeNotify();
    } catch (e) {
      debugPrint('ClosureService: load error: $e');
    }
  }

  Future<void> loadMonthClosures(int year, int month) async {
    try {
      final db = await _localDb.database;
      final start = '$year-${month.toString().padLeft(2, "0")}-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final end = '$year-${month.toString().padLeft(2, "0")}-${lastDay.toString().padLeft(2, "0")}';

      final rows = await db.query(
        'day_closures',
        where: 'date >= ? AND date <= ?',
        whereArgs: [start, end],
      );

      for (final row in rows) {
        _dailyClosures[row['date'] as String] = ClosureInfo.fromMap(row);
      }

      final mRows = await db.query(
        'month_closures',
        where: 'year = ? AND month = ?',
        whereArgs: [year, month],
      );
      if (mRows.isNotEmpty) {
        _monthlyClosures['$year-${month.toString().padLeft(2, "0")}'] = MonthlyClosureInfo(
          year: year,
          month: month,
          status: mRows.first['status'] as String? ?? 'ABIERTO',
          closedBy: mRows.first['closed_by'] as String? ?? '',
          closedAt: mRows.first['closed_at'] as String?,
          notes: mRows.first['notes'] as String?,
          daysOpen: daysInMonth - (mRows.first['days_closed'] as int? ?? 0),
          daysClosed: mRows.first['days_closed'] as int? ?? 0,
        );
      }
      _safeNotify();
    } catch (e) {
      debugPrint('ClosureService: loadMonth error: $e');
    }
  }

  Future<ClosureInfo> closeDay(String date, User user, {String? notes}) async {
    final db = await _localDb.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = _dailyClosures[date];

    if (existing != null && existing.isClosed && !existing.isReopened) {
      throw Exception('El dia $date ya esta cerrado');
    }

    final id = existing?.id ?? 'dc-${date}-${_uuid.v4().substring(0, 8)}';
    final closure = ClosureInfo(
      id: id,
      date: date,
      status: 'CERRADO',
      closedBy: user.nombre,
      closedAt: now,
      notes: notes ?? existing?.notes,
      reopenLog: existing?.reopenLog ?? [],
    );

    await db.insert('day_closures', closure.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _dailyClosures[date] = closure;

    if (existing != null) {
      await _localDb.queueSyncAction(
        action: 'UPDATE',
        entity: 'day_closures',
        entityId: id,
        data: closure.toMap(),
      );
    } else {
      await _localDb.queueSyncAction(
        action: 'CREATE',
        entity: 'day_closures',
        entityId: id,
        data: closure.toMap(),
      );
    }

    await _logAudit('CLOSE_DAY', user.id, {
      'date': date,
      'closed_by': user.nombre,
      'notes': notes,
    });

    _safeNotify();
    return closure;
  }

  Future<ClosureInfo> reopenDay(String date, User user, {required String motivo}) async {
    final db = await _localDb.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final existing = _dailyClosures[date];

    if (existing == null) {
      throw Exception('El dia $date no esta cerrado');
    }

    final closedAt = DateTime.parse(existing.closedAt);
    final daysSinceClose = DateTime.now().difference(closedAt).inDays;
    if (daysSinceClose > 3) {
      throw Exception('No se puede reabrir: han pasado mas de 3 dias desde el cierre');
    }

    final reopenEntry = {
      'type': 'reopen',
      'date': now,
      'user': user.nombre,
      'user_id': user.id,
      'motivo': motivo,
    };

    existing.reopenLog.add(reopenEntry);
    existing.status = 'REABIERTO';
    existing.closedBy = user.nombre;

    await db.insert('day_closures', existing.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    _dailyClosures[date] = existing;

    await _localDb.queueSyncAction(
      action: 'UPDATE',
      entity: 'day_closures',
      entityId: existing.id,
      data: existing.toMap(),
    );

    await _logAudit('REOPEN_DAY', user.id, {
      'date': date,
      'reopened_by': user.nombre,
      'motivo': motivo,
      'reopen_count': existing.reopenLog.length,
    });

    _safeNotify();
    return existing;
  }

  Future<MonthlyClosureInfo> closeMonth(int year, int month, User user, {String? notes}) async {
    final db = await _localDb.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final key = '$year-${month.toString().padLeft(2, "0")}';
    final lastDay = DateTime(year, month + 1, 0).day;
    final daysInMonth = lastDay;

    int closedCount = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final dateStr = '$year-${month.toString().padLeft(2, "0")}-${d.toString().padLeft(2, "0")}';
      if (_dailyClosures[dateStr]?.isClosed == true) closedCount++;
    }

    final closure = MonthlyClosureInfo(
      year: year,
      month: month,
      status: 'CERRADO',
      closedBy: user.nombre,
      closedAt: now,
      notes: notes,
      daysOpen: daysInMonth - closedCount,
      daysClosed: closedCount,
    );

    await db.insert('month_closures', {
      'id': 'mc-$key',
      'year': year,
      'month': month,
      'status': 'CERRADO',
      'closed_by': user.nombre,
      'closed_at': now,
      'notes': notes,
      'days_total': daysInMonth,
      'days_closed': closedCount,
      'reopen_log_json': '[]',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    _monthlyClosures[key] = closure;

    await _logAudit('CLOSE_MONTH', user.id, {
      'year': year,
      'month': month,
      'closed_by': user.nombre,
      'days_closed': closedCount,
      'days_total': daysInMonth,
    });

    _safeNotify();
    return closure;
  }

  Future<MonthlyClosureInfo> reopenMonth(int year, int month, User user, {required String motivo}) async {
    if (user.rol != 'ADMIN') {
      throw Exception('Solo el ADMIN puede reabrir meses cerrados');
    }

    final db = await _localDb.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final key = '$year-${month.toString().padLeft(2, "0")}';

    await db.delete('month_closures', where: 'year = ? AND month = ?', whereArgs: [year, month]);
    _monthlyClosures.remove(key);

    await _logAudit('REOPEN_MONTH', user.id, {
      'year': year,
      'month': month,
      'reopened_by': user.nombre,
      'motivo': motivo,
    });

    _safeNotify();
    return MonthlyClosureInfo(year: year, month: month, status: 'ABIERTO', closedBy: user.nombre);
  }

  Future<void> _logAudit(String action, String userId, Map<String, dynamic> details) async {
    try {
      final db = await _localDb.database;
      await db.insert('audit_log', {
        'id': 'audit-${DateTime.now().microsecondsSinceEpoch}',
        'action': action,
        'user_id': userId,
        'device_id': '',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'details_json': jsonEncode(details),
      });
    } catch (_) {}
  }

  List<Map<String, dynamic>> getDailyStatusesForMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final statuses = <Map<String, dynamic>>[];
    for (int d = 1; d <= lastDay; d++) {
      final dateStr = '$year-${month.toString().padLeft(2, "0")}-${d.toString().padLeft(2, "0")}';
      final closure = _dailyClosures[dateStr];
      String status = 'ABIERTO';
      if (closure != null) {
        if (closure.isReopened) {
          status = 'REABIERTO';
        } else if (closure.isClosed) {
          status = 'CERRADO';
        }
      }
      statuses.add({'date': dateStr, 'day': d, 'status': status, 'closure': closure});
    }
    return statuses;
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
