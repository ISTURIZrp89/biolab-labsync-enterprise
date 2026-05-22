import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/db.dart';
import '../../data/repositories/form_repository_impl.dart';
import '../../domain/form_definitions.dart';
import '../../security/auth_service.dart';
import '../../theme/omni_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();
  String? _selectedModule;
  List<Map<String, dynamic>> _entries = [];
  bool _loading = false;
  bool _generated = false;
  int _totalEntries = 0;
  final Map<String, int> _moduleBreakdown = {};
  final Set<String> _datesInRange = {};

  static const _allModules = [
    'incubadoras',
    'autoclaves',
    'ultracongeladores',
    'equipos',
    'procesamiento',
    'bitacora',
  ];
  List<String> _moduleOptions = [];

  String get _moduleLabel {
    if (_selectedModule == null) return 'Todos los modulos';
    final mod = findModule(_selectedModule!);
    return mod['label'] as String? ?? _selectedModule!;
  }

  @override
  void initState() {
    super.initState();
    _loadPermissions();
    _loadReport();
  }

  Future<void> _loadPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final auth = context.read<AuthService>();
      final userId = auth.currentUser?.id;
      final raw = prefs.getString('users_list');
      if (raw != null && userId != null) {
        final list = jsonDecode(raw) as List;
        for (final u in list) {
          if ((u as Map)['pin'] == userId || u['id'] == userId) {
            final p = u['permisos'] as String? ?? 'todos';
            if (p == 'todos') {
              _moduleOptions = List.from(_allModules);
            } else {
              _moduleOptions = p.split(',');
            }
            if (mounted) setState(() {});
            return;
          }
        }
      }
    } catch (_) {}
    _moduleOptions = List.from(_allModules);
    if (mounted) setState(() {});
  }

  Future<void> _loadReport() async {
    setState(() => _loading = true);
    try {
      final db = await LocalDatabase.instance.database;
      final s = _startDate.toIso8601String().split('T')[0];
      final e = _endDate.toIso8601String().split('T')[0];

      String where;
      List<dynamic> args;
      if (_selectedModule != null) {
        where = 'date >= ? AND date <= ? AND module = ?';
        args = [s, e, _selectedModule];
      } else {
        where = 'date >= ? AND date <= ?';
        args = [s, e];
      }

      final rows = await db.query('form_entries', where: where, whereArgs: args, orderBy: 'date ASC');
      _entries = rows;
      _totalEntries = rows.length;

      final breakdown = <String, int>{};
      final dates = <String>{};
      for (final row in rows) {
        final mod = row['module'] as String? ?? '?';
        breakdown[mod] = (breakdown[mod] ?? 0) + 1;
        final d = row['date'] as String? ?? '';
        if (d.isNotEmpty) dates.add(d);
      }

      if (mounted) setState(() {
        _moduleBreakdown..clear()..addAll(breakdown);
        _datesInRange..clear()..addAll(dates);
        _generated = true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OmniTheme.red400));
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(data: OmniTheme.theme.copyWith(
        colorScheme: OmniTheme.theme.colorScheme.copyWith(primary: OmniTheme.accentBlue),
      ), child: child!),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      _loadReport();
    }
  }

  Future<String> _getReportsDir() async {
    final prefs = await SharedPreferences.getInstance();
    final savePath = prefs.getString('save_path');
    if (savePath != null && savePath.isNotEmpty) {
      final dir = Directory(savePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      return savePath;
    }
    return '.';
  }

  Future<void> _exportPdf() async {
    try {
      final auth = context.read<AuthService>();
      final user = auth.currentUser;
      final pdf = pw.Document();
      final fmt = DateFormat('dd/MM/yyyy');
      final now = DateTime.now();
      final folio = 'BL-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${now.hour}${now.minute}${now.second}';

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (ctx) => pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.SizedBox(height: 60),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 40),
              decoration: pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 3)),
              ),
              child: pw.Column(children: [
                pw.Text('BIOLAB LABSYNC', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 4),
                pw.Text('Sistema de Gestión de Laboratorio', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey600)),
              ]),
            ),
            pw.SizedBox(height: 40),
            pw.Text('REPORTE DE ACTIVIDADES', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.SizedBox(height: 8),
            pw.Container(
              width: 80, height: 3,
              color: PdfColors.blue800,
            ),
            pw.SizedBox(height: 30),
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildCoverRow('Folio:', folio),
                  _buildCoverRow('Emisión:', fmt.format(now)),
                  _buildCoverRow('Período:', '${fmt.format(_startDate)} - ${fmt.format(_endDate)}'),
                  _buildCoverRow('Módulo:', _moduleLabel),
                  _buildCoverRow('Elaborado por:', user != null ? '${user.nombre} (${user.rol})${user.cargoOperativo.isNotEmpty ? ' - ${user.cargoOperativo}' : ''}' : '-'),
                  _buildCoverRow('Total registros:', '$_totalEntries'),
                ],
              ),
            ),
            pw.Spacer(),
            pw.Text('BioLab LABSYNC - Documento Controlado', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Este documento es propiedad de BioLab LABSYNC', style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
            pw.SizedBox(height: 20),
          ],
        ),
      ));
      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blue800, width: 2)),
          ),
          padding: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BIOLAB LABSYNC', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text('Sistema de Gestión de Laboratorio', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('Folio: $folio', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Emisión: ${fmt.format(now)}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ]),
          ]),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
          ),
          padding: const pw.EdgeInsets.only(top: 6),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('BioLab LABSYNC - Documento Controlado', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
            pw.Text('Pág. ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ]),
        ),
        build: (ctx) => [
          pw.Header(text: 'REPORTE DE ACTIVIDADES', level: 0),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Período:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('${fmt.format(_startDate)} - ${fmt.format(_endDate)}', style: const pw.TextStyle(fontSize: 9)),
              ]),
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Módulo:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(_moduleLabel, style: const pw.TextStyle(fontSize: 9)),
              ]),
              if (user != null) ...[
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('Elaborado por:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${user.nombre} (${user.rol})', style: const pw.TextStyle(fontSize: 9)),
                ]),
              ],
              pw.SizedBox(height: 4),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text('Total registros:', style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text('$_totalEntries', style: const pw.TextStyle(fontSize: 9, color: PdfColors.blue800)),
              ]),
            ]),
          ),
          pw.SizedBox(height: 20),
          pw.Header(text: 'Resumen por módulo', level: 1),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.center},
            headers: ['Módulo', 'Registros'],
            data: _moduleBreakdown.entries.map((e) {
              final mod = findModule(e.key);
              return [mod['label'] as String? ?? e.key, '${e.value}'];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(text: 'Detalle de registros', level: 1),
          ..._buildPdfEntryTable(pdf, fmt),
        ],
      ));

      final dir = await _getReportsDir();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(now);
      final file = File('$dir/LABSYNC_Reporte_$ts.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        final bytes = await pdf.save();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF ISO generado: ${file.path}'),
          backgroundColor: OmniTheme.green400,
          action: SnackBarAction(label: 'COMPARTIR', onPressed: () => Printing.sharePdf(bytes: bytes, filename: file.path.split('\\').last)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error PDF: $e'), backgroundColor: OmniTheme.red400));
    }
  }

  pw.Widget _buildCoverRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
      ]),
    );
  }

  List<pw.Widget> _buildPdfEntryTable(pw.Document pdf, DateFormat fmt) {
    if (_entries.isEmpty) return [pw.Paragraph(text: 'Sin registros en el periodo.')];

    final data = <List<String>>[];
    for (final row in _entries) {
      final mod = row['module'] as String? ?? '';
      final date = row['date'] as String? ?? '';
      final dataJson = row['data_json'] as String? ?? '{}';
      Map<String, dynamic> dataMap = {};
      try { dataMap = jsonDecode(dataJson) as Map<String, dynamic>; } catch (_) {}
      final user = dataMap['responsable'] as String? ?? dataMap['usuario'] as String? ?? dataMap['nombre'] as String? ?? '-';
      final act = dataMap['actividad'] as String? ?? dataMap['observaciones'] as String? ?? '-';
      data.add([mod, date, user, act.length > 60 ? '${act.substring(0, 60)}...' : act]);
    }

    return [
      pw.TableHelper.fromTextArray(
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        headers: ['Modulo', 'Fecha', 'Responsable', 'Actividad'],
        data: data,
      ),
    ];
  }

  Future<void> _exportExcel() async {
    try {
      final excel = Excel.createExcel();
      final sheet = excel['Reporte'];
      final fmt = DateFormat('dd/MM/yyyy');

      sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('BioLab LABSYNC - Reporte $_moduleLabel');
      sheet.cell(CellIndex.indexByString('A2')).value = TextCellValue('Periodo: ${fmt.format(_startDate)} - ${fmt.format(_endDate)}');
      sheet.cell(CellIndex.indexByString('A3')).value = TextCellValue('Total registros: $_totalEntries');
      sheet.cell(CellIndex.indexByString('A4')).value = TextCellValue('');

      sheet.cell(CellIndex.indexByString('A5')).value = TextCellValue('Modulo');
      sheet.cell(CellIndex.indexByString('B5')).value = TextCellValue('Fecha');
      sheet.cell(CellIndex.indexByString('C5')).value = TextCellValue('Responsable');
      sheet.cell(CellIndex.indexByString('D5')).value = TextCellValue('Actividad');
      sheet.cell(CellIndex.indexByString('E5')).value = TextCellValue('Datos');

      int rowIdx = 6;
      for (final row in _entries) {
        final mod = row['module'] as String? ?? '';
        final date = row['date'] as String? ?? '';
        final dataJson = row['data_json'] as String? ?? '{}';
        Map<String, dynamic> dataMap = {};
        try { dataMap = jsonDecode(dataJson) as Map<String, dynamic>; } catch (_) {}
        final user = dataMap['responsable'] as String? ?? dataMap['usuario'] as String? ?? dataMap['nombre'] as String? ?? '-';
        final act = dataMap['actividad'] as String? ?? dataMap['observaciones'] as String? ?? '';
        final allData = dataMap.entries.where((e) => e.value != null && e.value.toString().isNotEmpty).map((e) => '${e.key}: ${e.value}').join('; ');

        sheet.cell(CellIndex.indexByString('A$rowIdx')).value = TextCellValue(mod);
        sheet.cell(CellIndex.indexByString('B$rowIdx')).value = TextCellValue(date);
        sheet.cell(CellIndex.indexByString('C$rowIdx')).value = TextCellValue(user);
        sheet.cell(CellIndex.indexByString('D$rowIdx')).value = TextCellValue(act);
        sheet.cell(CellIndex.indexByString('E$rowIdx')).value = TextCellValue(allData);
        rowIdx++;
      }

      final dir = await _getReportsDir();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$dir/LABSYNC_Reporte_$ts.xlsx';
      final excelBytes = excel.encode();
      if (excelBytes != null) {
        await File(filePath).writeAsBytes(excelBytes);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Excel guardado: $filePath'),
          backgroundColor: OmniTheme.green400,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error Excel: $e'), backgroundColor: OmniTheme.red400));
    }
  }

  Future<void> _showBatchExportDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Exportacion por lotes', style: TextStyle(color: OmniTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Generar reportes separados para cada periodo dentro del rango:', style: TextStyle(color: OmniTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.calendar_view_week, color: OmniTheme.accentBlue),
              title: const Text('Por semana', style: TextStyle(color: OmniTheme.textPrimary)),
              subtitle: const Text('Un reporte por cada semana', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'week'),
            ),
            const Divider(height: 1, color: OmniTheme.bg800),
            ListTile(
              leading: const Icon(Icons.calendar_month, color: OmniTheme.green400),
              title: const Text('Por mes', style: TextStyle(color: OmniTheme.textPrimary)),
              subtitle: const Text('Un reporte por cada mes', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
              onTap: () => Navigator.pop(ctx, 'month'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
        ],
      ),
    );

    if (result != null && mounted) {
      _batchExport(result);
    }
  }

  Future<void> _batchExport(String period) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final fmt = DateFormat('yyyyMMdd');
      final displayFmt = DateFormat('dd/MM/yyyy');
      final periods = <Map<String, dynamic>>[];
      var cursor = DateTime(_startDate.year, _startDate.month, _startDate.day);

      if (period == 'week') {
        while (cursor.isBefore(_endDate) || cursor.isAtSameMomentAs(_endDate)) {
          var weekEnd = cursor.add(const Duration(days: 6));
          if (weekEnd.isAfter(_endDate)) weekEnd = _endDate;
          periods.add({'label': 'Sem ${displayFmt.format(cursor)}', 'start': cursor, 'end': weekEnd});
          cursor = weekEnd.add(const Duration(days: 1));
        }
      } else {
        while (cursor.isBefore(_endDate) || cursor.isAtSameMomentAs(_endDate)) {
          final monthEnd = DateTime(cursor.year, cursor.month + 1, 0);
          final end = monthEnd.isBefore(_endDate) ? monthEnd : _endDate;
          periods.add({'label': '${_monthName(cursor.month)} ${cursor.year}', 'start': cursor, 'end': end});
          cursor = DateTime(cursor.year, cursor.month + 1, 1);
        }
      }

      final dir = await _getReportsDir();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      int generated = 0;
      final filePaths = <String>[];

      for (final p in periods) {
        final s = (p['start'] as DateTime).toIso8601String().split('T')[0];
        final e = (p['end'] as DateTime).toIso8601String().split('T')[0];
        final label = p['label'] as String;

        final db = await LocalDatabase.instance.database;
        String where;
        List<dynamic> args;
        if (_selectedModule != null) {
          where = 'date >= ? AND date <= ? AND module = ?';
          args = [s, e, _selectedModule];
        } else {
          where = 'date >= ? AND date <= ?';
          args = [s, e];
        }

                final rows = await db.query('form_entries', where: where, whereArgs: args, orderBy: 'date ASC');
        if (rows.isEmpty) continue;

        final auth = context.read<AuthService>();
        final user = auth.currentUser;
        final pdf = pw.Document();
        pdf.addPage(pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (ctx) => pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('BioLab LABSYNC - $label', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text('Reporte $_moduleLabel', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            ]),
          ),
          footer: (ctx) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Text('Pagina ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
          ),
          build: (ctx) => [
            pw.Paragraph(text: 'Periodo: ${displayFmt.format(p['start'])} - ${displayFmt.format(p['end'])}'),
            if (user != null) pw.Paragraph(text: 'Elaborado por: ${user.nombre} (${user.rol})'),
            pw.Paragraph(text: 'Total registros: ${rows.length}'),
            pw.SizedBox(height: 12),
            pw.Header(text: 'Detalle', level: 1),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              headers: ['Modulo', 'Fecha', 'Responsable', 'Actividad'],
              data: rows.map((row) {
                final mod = row['module'] as String? ?? '';
                final date = row['date'] as String? ?? '';
                Map<String, dynamic> dataMap = {};
                try { dataMap = jsonDecode(row['data_json'] as String); } catch (_) {}
                final user = dataMap['responsable'] as String? ?? dataMap['usuario'] as String? ?? dataMap['nombre'] as String? ?? '-';
                final act = dataMap['actividad'] as String? ?? dataMap['observaciones'] as String? ?? '-';
                return [mod, date, user, act.length > 60 ? '${act.substring(0, 60)}...' : act];
              }).toList(),
            ),
          ],
        ));

        final filePath = '$dir/LABSYNC_${label.replaceAll(' ', '_')}_$ts.pdf';
        await File(filePath).writeAsBytes(await pdf.save());
        filePaths.add(filePath);
        generated++;
      }

      if (mounted) Navigator.pop(context);

      if (generated > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$generated reportes generados en $dir'),
          backgroundColor: OmniTheme.green400,
          duration: const Duration(seconds: 4),
        ));
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sin registros para exportar'), backgroundColor: OmniTheme.orange400));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error batch: $e'), backgroundColor: OmniTheme.red400));
      }
    }
  }

  String _monthName(int m) {
    const months = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];
    return months[m - 1];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reportes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: OmniTheme.bg900,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf, size: 20), tooltip: 'Exportar PDF', onPressed: _entries.isEmpty ? null : _exportPdf, color: OmniTheme.red400),
          IconButton(icon: const Icon(Icons.table_chart, size: 20), tooltip: 'Exportar Excel', onPressed: _entries.isEmpty ? null : _exportExcel, color: OmniTheme.green400),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: OmniTheme.textMuted),
            color: OmniTheme.bg800,
            onSelected: (v) {
              if (v == 'batch') _showBatchExportDialog();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'batch', child: ListTile(
                leading: Icon(Icons.layers, size: 18, color: OmniTheme.accentBlue),
                title: Text('Exportacion por lotes', style: TextStyle(fontSize: 12, color: OmniTheme.textPrimary)),
                dense: true,
              )),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(height: 1, color: OmniTheme.bg800),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final fmt = DateFormat('dd/MM/yyyy');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      color: OmniTheme.bg900,
      child: Row(
        children: [
          InkWell(
            onTap: _pickDateRange,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.date_range, size: 16, color: OmniTheme.accentBlue),
                const SizedBox(width: 8),
                Text('${fmt.format(_startDate)} - ${fmt.format(_endDate)}', style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down, size: 16, color: OmniTheme.textMuted),
              ]),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(border: Border.all(color: OmniTheme.bg700), borderRadius: BorderRadius.circular(8)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: _selectedModule,
                dropdownColor: OmniTheme.bg800,
                style: const TextStyle(fontSize: 12, color: OmniTheme.textPrimary),
                hint: const Text('Todos los modulos', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Todos los modulos', style: TextStyle(fontSize: 12))),
                  ..._moduleOptions.map((m) {
                    final mod = findModule(m);
                    return DropdownMenuItem(value: m, child: Text(mod['label'] as String? ?? m, style: const TextStyle(fontSize: 12)));
                  }),
                ],
                onChanged: (v) { setState(() => _selectedModule = v); _loadReport(); },
              ),
            ),
          ),
          const Spacer(),
          Text('$_totalEntries registros', style: const TextStyle(fontSize: 11, color: OmniTheme.textMuted)),
          const SizedBox(width: 12),
          if (_loading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (!_generated) return const Center(child: Text('Selecciona un rango de fechas', style: TextStyle(color: OmniTheme.textMuted)));
    if (_entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: OmniTheme.bg700),
            const SizedBox(height: 12),
            const Text('Sin registros en el periodo seleccionado', style: TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSummaryCards(),
        const SizedBox(height: 16),
        _buildDetailTable(),
      ],
    );
  }

  Widget _buildSummaryCards() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _statCard('Total registros', '$_totalEntries', Icons.assignment, OmniTheme.accentBlue),
        _statCard('Dias con datos', '${_datesInRange.length}', Icons.calendar_today, OmniTheme.green400),
        _statCard('Modulos activos', '${_moduleBreakdown.length}', Icons.category, OmniTheme.yellow400),
        ..._moduleBreakdown.entries.map((e) {
          final mod = findModule(e.key);
          return _statCard(mod['label'] as String? ?? e.key, '${e.value}', Icons.folder, OmniTheme.accentIndigo);
        }),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmniTheme.bg900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmniTheme.bg800),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: const TextStyle(fontSize: 9, color: OmniTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTable() {
    return Container(
      decoration: BoxDecoration(
        color: OmniTheme.bg900,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: OmniTheme.bg800),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(OmniTheme.bg800),
            columnSpacing: 20,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 48,
            columns: const [
              DataColumn(label: Text('Fecha', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted))),
              DataColumn(label: Text('Modulo', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted))),
              DataColumn(label: Text('Responsable', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted))),
              DataColumn(label: Text('Actividad', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: OmniTheme.textMuted))),
            ],
            rows: _entries.map((row) {
              final dataJson = row['data_json'] as String? ?? '{}';
              Map<String, dynamic> dataMap = {};
              try { dataMap = jsonDecode(dataJson) as Map<String, dynamic>; } catch (_) {}
              final user = dataMap['responsable'] as String? ?? dataMap['usuario'] as String? ?? dataMap['nombre'] as String? ?? '-';
              final act = dataMap['actividad'] as String? ?? dataMap['observaciones'] as String? ?? dataMap['notas'] as String? ?? '';
              return DataRow(cells: [
                DataCell(Text(row['date'] as String? ?? '', style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                DataCell(Text(row['module'] as String? ?? '', style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                DataCell(Text(user, style: const TextStyle(fontSize: 11, color: OmniTheme.textPrimary))),
                DataCell(Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(act, style: const TextStyle(fontSize: 11, color: OmniTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
