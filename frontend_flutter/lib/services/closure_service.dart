import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';
import '../domain/entities/user.dart';
import 'backup_service.dart';

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
          daysOpen: lastDay - (mRows.first['days_closed'] as int? ?? 0),
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

    await db.transaction((txn) async {
      await txn.insert('day_closures', closure.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
      _dailyClosures[date] = closure;

      if (existing != null) {
        await _localDb.queueSyncAction(
          action: 'UPDATE', entity: 'day_closures', entityId: id, data: closure.toMap(),
        );
      } else {
        await _localDb.queueSyncAction(
          action: 'CREATE', entity: 'day_closures', entityId: id, data: closure.toMap(),
        );
      }

      await _logAuditTxn(txn, 'CLOSE_DAY', user.id, {
        'date': date, 'closed_by': user.nombre, 'notes': notes,
      });
    });

    await BackupService().backupDaily(date);

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
    final hoursSinceClose = DateTime.now().difference(closedAt).inHours;
    if (hoursSinceClose > 24) {
      throw Exception('No se puede reabrir: han pasado mas de 24 horas desde el cierre');
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
    final updated = ClosureInfo(
      id: existing.id,
      date: existing.date,
      status: 'REABIERTO',
      closedBy: user.nombre,
      closedAt: DateTime.now().toUtc().toIso8601String(),
      notes: existing.notes,
      reopenLog: List.from(existing.reopenLog),
    );

    await BackupService().backupDaily(date);

    await db.transaction((txn) async {
      await txn.insert('day_closures', updated.toMap(), conflictAlgorithm: ConflictAlgorithm.fail);
      _dailyClosures[date] = updated;

      await _localDb.queueSyncAction(
        action: 'UPDATE', entity: 'day_closures', entityId: existing.id, data: existing.toMap(),
      );

      await _logAuditTxn(txn, 'REOPEN_DAY', user.id, {
        'date': date, 'reopened_by': user.nombre, 'motivo': motivo,
        'reopen_count': existing.reopenLog.length,
      });
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

    await db.transaction((txn) async {
      await txn.insert('month_closures', {
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
      }, conflictAlgorithm: ConflictAlgorithm.fail);

      _monthlyClosures[key] = closure;

      await _logAuditTxn(txn, 'CLOSE_MONTH', user.id, {
        'year': year,
        'month': month,
        'closed_by': user.nombre,
        'days_closed': closedCount,
        'days_total': daysInMonth,
      });
    });

    _generateMonthlyReport(year, month, user);

    await BackupService().backupMonthly(year, month);

    if (month == 12) {
      await BackupService().backupAnnual(year);
    }

    _safeNotify();
    return closure;
  }

  Future<void> _generateMonthlyReport(int year, int month, User user) async {
    try {
      final db = await _localDb.database;
      final prefs = await SharedPreferences.getInstance();
      final savePath = prefs.getString('save_path') ?? '';
      if (savePath.isEmpty) return;

      String companyName = '';
      String logoBase64 = '';
      List<String> personnel = [];
      try {
        final rows = await db.query('company_info', where: 'id = ?', whereArgs: ['default']);
        if (rows.isNotEmpty) {
          companyName = rows.first['company_name'] as String? ?? '';
          logoBase64 = rows.first['logo_base64'] as String? ?? '';
          final raw = rows.first['personnel_json'] as String? ?? '[]';
          personnel = (jsonDecode(raw) as List).cast<String>();
        }
      } catch (_) {}

      final start = '$year-${month.toString().padLeft(2, "0")}-01';
      final lastDay = DateTime(year, month + 1, 0).day;
      final end = '$year-${month.toString().padLeft(2, "0")}-${lastDay.toString().padLeft(2, "0")}';

      final entries = await db.query('form_entries',
        where: 'date >= ? AND date <= ?',
        whereArgs: [start, end],
        orderBy: 'date ASC',
      );

      final monthNames = ['', 'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO', 'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
      final pdf = pw.Document();
      final fmt = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();
      final displayName = companyName.isNotEmpty ? companyName : 'BIOLAB LABSYNC';

      int closedCount = 0;
      for (int d = 1; d <= lastDay; d++) {
        final ds = '$year-${month.toString().padLeft(2, "0")}-${d.toString().padLeft(2, "0")}';
        if (_dailyClosures[ds]?.isClosed == true) closedCount++;
      }

      final moduleNames = {
        'bitacora': 'Bitacora General', 'procesamiento': 'Procesamiento',
        'incubadoras': 'Incubadoras', 'ultracongeladores': 'Ultracongeladores',
        'equipos': 'Equipos', 'autoclaves': 'Autoclaves', 'solucion_cobre': 'Solucion de Cobre',
      };
      final moduleCounts = <String, int>{};
      for (final e in entries) {
        final mod = e['module'] as String? ?? '';
        moduleCounts[mod] = (moduleCounts[mod] ?? 0) + 1;
      }

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            if (logoBase64.isNotEmpty)
              pw.Image(pw.MemoryImage(base64Decode(logoBase64)), height: 80, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 20),
            pw.Text(displayName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.Container(width: 80, height: 3, color: PdfColors.blue800),
            pw.SizedBox(height: 30),
            pw.Text('BITACORA DE ${monthNames[month]} $year', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(color: PdfColors.grey50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pReportRow('Mes:', '${monthNames[month]} $year'),
                _pReportRow('Periodo:', '${fmt.format(DateTime(year, month, 1))} - ${fmt.format(DateTime(year, month, lastDay))}'),
                _pReportRow('Total registros:', '${entries.length}'),
                _pReportRow('Dias cerrados:', '$closedCount de $lastDay'),
                _pReportRow('Fecha de cierre:', fmt.format(now)),
              ]),
            ),
            pw.SizedBox(height: 20),
            if (personnel.isNotEmpty) ...[
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text('Personal Responsable:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
              pw.SizedBox(height: 4),
              ...personnel.map((p) => pw.Text('  - $p', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))),
            ],
            pw.Spacer(),
            pw.Text('$displayName - Documento Controlado', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Generado automaticamente por LABSYNC', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
          ],
        ),
      ));

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2))),
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(displayName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('${monthNames[month]} $year', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('$displayName - Documento Controlado', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            pw.Text('Pag. ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ]),
        ),
        build: (ctx) => [
          pw.Header(text: 'RESUMEN DEL MES', level: 0),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
            headers: ['Modulo', 'Registros'],
            data: moduleNames.entries.map((e) {
              final count = moduleCounts[e.key] ?? 0;
              return [e.value, '$count'];
            }).where((r) => r[1] != '0').toList(),
          ),
          if (moduleCounts.isEmpty) pw.Paragraph(text: 'Sin registros en el periodo.'),
          pw.SizedBox(height: 20),
          pw.Header(text: 'DETALLE POR MODULO', level: 1),
          ..._buildMonthlyEntryByModule(entries),
        ],
      ));

      final dir = Directory(savePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final fileName = 'Bitacora_de_${monthNames[month]}_$year.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      debugPrint('Reporte mensual generado: ${file.path}');
    } catch (e) {
      debugPrint('Error generando reporte mensual: $e');
    }
  }

  List<pw.Widget> _buildMonthlyEntryByModule(List<Map<String, dynamic>> entries) {
    if (entries.isEmpty) return [pw.Paragraph(text: 'Sin registros en el periodo.')];
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final e in entries) {
      final mod = e['module'] as String? ?? 'otros';
      grouped.putIfAbsent(mod, () => []).add(e);
    }
    final moduleNames = {
      'bitacora': 'Bitacora General', 'procesamiento': 'Procesamiento',
      'incubadoras': 'Incubadoras', 'ultracongeladores': 'Ultracongeladores',
      'equipos': 'Equipos', 'autoclaves': 'Autoclaves', 'solucion_cobre': 'Solucion de Cobre',
      'muestras': 'Muestras',
    };
    final order = ['incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'solucion_cobre', 'muestras'];
    final widgets = <pw.Widget>[];
    for (final mod in order) {
      final modEntries = grouped[mod];
      if (modEntries == null || modEntries.isEmpty) continue;
      final label = moduleNames[mod] ?? mod;
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: const pw.BoxDecoration(color: PdfColors.blue50),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text('${modEntries.length} registro${modEntries.length == 1 ? '' : 's'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        ]),
      ));
      final data = <List<String>>[];
      for (final row in modEntries) {
        final date = row['date'] as String? ?? '';
        Map<String, dynamic> dataMap = {};
        try { dataMap = jsonDecode(row['data_json'] as String) as Map<String, dynamic>; } catch (_) {}
        final user = dataMap['responsable'] as String? ?? dataMap['usuario'] as String? ?? dataMap['nombre'] as String? ?? '-';
        final act = dataMap['actividad'] as String? ?? dataMap['observaciones'] as String? ?? dataMap['incidencias'] as String? ?? '-';
        data.add([date, user, act.length > 60 ? '${act.substring(0, 60)}...' : act]);
      }
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.centerLeft, 2: pw.Alignment.centerLeft},
        headers: ['Fecha', 'Responsable', 'Actividad'],
        data: data,
      ));
    }
    if (grouped.containsKey('otros')) {
      final otros = grouped['otros']!;
      widgets.add(pw.SizedBox(height: 12));
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        child: pw.Text('Otros (${otros.length})', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      ));
      final data = <List<String>>[];
      for (final row in otros) {
        final mod = row['module'] as String? ?? '';
        final date = row['date'] as String? ?? '';
        Map<String, dynamic> dataMap = {};
        try { dataMap = jsonDecode(row['data_json'] as String) as Map<String, dynamic>; } catch (_) {}
        final user = dataMap['responsable'] as String? ?? dataMap['usuario'] as String? ?? dataMap['nombre'] as String? ?? '-';
        final act = dataMap['actividad'] as String? ?? dataMap['observaciones'] as String? ?? dataMap['incidencias'] as String? ?? '-';
        data.add([mod, date, user, act.length > 50 ? '${act.substring(0, 50)}...' : act]);
      }
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 7.5, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.grey600),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.centerLeft, 3: pw.Alignment.centerLeft},
        headers: ['Modulo', 'Fecha', 'Responsable', 'Actividad'],
        data: data,
      ));
    }
    return widgets;
  }

  pw.Widget _pReportRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
      ]),
    );
  }

  Future<MonthlyClosureInfo> reopenMonth(int year, int month, User user, {required String motivo}) async {
    if (user.rol != 'ADMIN') {
      throw Exception('Solo el ADMIN puede reabrir meses cerrados');
    }

    final db = await _localDb.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final key = '$year-${month.toString().padLeft(2, "0")}';

    await BackupService().backupMonthly(year, month);

    await db.transaction((txn) async {
      await txn.delete('month_closures', where: 'year = ? AND month = ?', whereArgs: [year, month]);
      _monthlyClosures.remove(key);

      await _logAuditTxn(txn, 'REOPEN_MONTH', user.id, {
        'year': year, 'month': month, 'reopened_by': user.nombre, 'motivo': motivo,
      });
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

  Future<void> _logAuditTxn(dynamic txn, String action, String userId, Map<String, dynamic> details) async {
    try {
      await txn.insert('audit_log', {
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

  Future<String?> generateAnnualReport(int year, User user) async {
    try {
      final db = await _localDb.database;
      final prefs = await SharedPreferences.getInstance();
      final savePath = prefs.getString('save_path') ?? '';
      if (savePath.isEmpty) return null;

      String companyName = '';
      String logoBase64 = '';
      try {
        final rows = await db.query('company_info', where: 'id = ?', whereArgs: ['default']);
        if (rows.isNotEmpty) {
          companyName = rows.first['company_name'] as String? ?? '';
          logoBase64 = rows.first['logo_base64'] as String? ?? '';
        }
      } catch (_) {}

      final monthNames = ['', 'ENERO', 'FEBRERO', 'MARZO', 'ABRIL', 'MAYO', 'JUNIO',
        'JULIO', 'AGOSTO', 'SEPTIEMBRE', 'OCTUBRE', 'NOVIEMBRE', 'DICIEMBRE'];
      final fmt = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();
      final displayName = companyName.isNotEmpty ? companyName : 'BIOLAB LABSYNC';

      final monthData = <Map<String, dynamic>>[];
      int totalEntries = 0;
      int totalDaysClosed = 0;
      int totalDaysInYear = 0;

      for (int m = 1; m <= 12; m++) {
        final lastDay = DateTime(year, m + 1, 0).day;
        totalDaysInYear += lastDay;

        final start = '$year-${m.toString().padLeft(2, "0")}-01';
        final end = '$year-${m.toString().padLeft(2, "0")}-${lastDay.toString().padLeft(2, "0")}';
        final entries = await db.query('form_entries',
          where: 'date >= ? AND date <= ?', whereArgs: [start, end],
          orderBy: 'date ASC');

        final mcKey = '$year-${m.toString().padLeft(2, "0")}';
        final mcRows = await db.query('month_closures',
          where: 'id = ?', whereArgs: ['mc-$mcKey']);

        bool closed = mcRows.isNotEmpty;
        int closedDays = 0;
        if (closed) {
          closedDays = (mcRows.first['days_closed'] as int? ?? 0);
          totalDaysClosed += closedDays;
        }

        final moduleCounts = <String, int>{};
        for (final e in entries) {
          final mod = e['module'] as String? ?? '';
          moduleCounts[mod] = (moduleCounts[mod] ?? 0) + 1;
        }

        monthData.add({
          'month': m,
          'monthName': monthNames[m],
          'entries': entries.length,
          'closed': closed,
          'closedDays': closedDays,
          'totalDays': lastDay,
          'moduleCounts': moduleCounts,
        });
        totalEntries += entries.length;
      }

      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          children: [
            if (logoBase64.isNotEmpty)
              pw.Image(pw.MemoryImage(base64Decode(logoBase64)), height: 80, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 20),
            pw.Text(displayName, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 8),
            pw.Container(width: 80, height: 3, color: PdfColors.blue800),
            pw.SizedBox(height: 30),
            pw.Text('REPORTE ANUAL $year', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(color: PdfColors.grey50, borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4))),
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                _pReportRow('Ano:', '$year'),
                _pReportRow('Total registros:', '$totalEntries'),
                _pReportRow('Dias cerrados:', '$totalDaysClosed de $totalDaysInYear'),
                _pReportRow('Meses cerrados:', '${monthData.where((m) => m['closed'] as bool).length} de 12'),
                _pReportRow('Fecha:', fmt.format(now)),
              ]),
            ),
            pw.Spacer(),
            pw.Text('$displayName - Documento Controlado', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Generado automaticamente por LABSYNC', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
          ],
        ),
      ));

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2))),
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(displayName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('Reporte Anual $year', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          ]),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5))),
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('$displayName - Documento Controlado', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            pw.Text('Pag. ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ]),
        ),
        build: (ctx) => [
          pw.Header(text: 'RESUMEN MENSUAL', level: 0),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {0: pw.Alignment.center, 1: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.center, 4: pw.Alignment.center},
            headers: ['Mes', 'Registros', 'Dias Cerrados', 'Cobertura', 'Estado'],
            data: monthData.map((md) => [
              md['monthName'],
              '${md['entries']}',
              '${md['closedDays']}/${md['totalDays']}',
              md['totalDays'] > 0 ? '${((md['closedDays'] as int) / (md['totalDays'] as int) * 100).toStringAsFixed(0)}%' : '-',
              md['closed'] ? 'Cerrado' : 'Abierto',
            ]).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(text: 'ESTADISTICAS POR MODULO', level: 1),
          pw.SizedBox(height: 8),
          ..._buildAnnualModuleTable(monthData),
        ],
      ));

      final dir = Directory(savePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final fileName = 'Reporte_Anual_$year.pdf';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(await pdf.save());
      debugPrint('Reporte anual generado: ${file.path}');
      return file.path;
    } catch (e) {
      debugPrint('Error generando reporte anual: $e');
      return null;
    }
  }

  List<pw.Widget> _buildAnnualModuleTable(List<Map<String, dynamic>> monthData) {
    final allModules = <String>{};
    for (final md in monthData) {
      allModules.addAll((md['moduleCounts'] as Map<String, int>).keys);
    }
    if (allModules.isEmpty) return [pw.Paragraph(text: 'Sin registros en el periodo.')];

    final sortedModules = allModules.toList()..sort();
    final moduleNames = {
      'bitacora': 'Bitacora General', 'procesamiento': 'Procesamiento',
      'incubadoras': 'Incubadoras', 'ultracongeladores': 'Ultracongeladores',
      'equipos': 'Equipos', 'autoclaves': 'Autoclaves', 'solucion_cobre': 'Solucion de Cobre',
      'muestras': 'Muestras',
    };

    final moduleTotals = <String, int>{};
    for (final mod in sortedModules) {
      moduleTotals[mod] = 0;
      for (final md in monthData) {
        moduleTotals[mod] = (moduleTotals[mod] ?? 0) + ((md['moduleCounts'] as Map<String, int>)[mod] ?? 0);
      }
    }

    return [
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
        cellStyle: const pw.TextStyle(fontSize: 8),
        cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center, 2: pw.Alignment.center},
        headers: ['Modulo', 'Total Anual', 'Promedio/Mes'],
        data: sortedModules.map((mod) => [
          moduleNames[mod] ?? mod,
          '${moduleTotals[mod]}',
          monthData.length > 0 ? '${(moduleTotals[mod]! / monthData.length).toStringAsFixed(1)}' : '0',
        ]).toList(),
      ),
    ];
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
