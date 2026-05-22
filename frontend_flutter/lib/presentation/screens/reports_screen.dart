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

  static const _moduleOptions = [
    'incubadoras',
    'autoclaves',
    'ultracongeladores',
    'equipos',
    'procesamiento',
    'bitacora',
  ];

  String get _moduleLabel {
    if (_selectedModule == null) return 'Todos los modulos';
    final mod = findModule(_selectedModule!);
    return mod['label'] as String? ?? _selectedModule!;
  }

  @override
  void initState() {
    super.initState();
    _loadReport();
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
      final pdf = pw.Document();
      final fmt = DateFormat('dd/MM/yyyy');
      final title = 'LABSYNC - Reporte ${_moduleLabel}';

      pdf.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (ctx) => pw.Container(
          alignment: pw.Alignment.centerLeft,
          margin: const pw.EdgeInsets.only(bottom: 12),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('BioLab LABSYNC', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.Text('Reporte de Actividades', style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700)),
          ]),
        ),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 12),
          child: pw.Text('Pagina ${ctx.pageNumber} de ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
        ),
        build: (ctx) => [
          pw.Paragraph(text: 'Periodo: ${fmt.format(_startDate)} - ${fmt.format(_endDate)}'),
          pw.SizedBox(height: 8),
          pw.Paragraph(text: 'Modulo: $_moduleLabel'),
          pw.Paragraph(text: 'Total de registros: $_totalEntries'),
          pw.SizedBox(height: 16),
          pw.Header(text: 'Resumen por modulo', level: 1),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headers: ['Modulo', 'Cantidad'],
            data: _moduleBreakdown.entries.map((e) => [e.key, '${e.value}']).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Header(text: 'Detalle de registros', level: 1),
          ..._buildPdfEntryTable(pdf, fmt),
        ],
      ));

      final dir = await _getReportsDir();
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('$dir/LABSYNC_Reporte_$ts.pdf');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        final bytes = await pdf.save();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('PDF guardado: ${file.path}'),
          backgroundColor: OmniTheme.green400,
          action: SnackBarAction(label: 'COMPARTIR', onPressed: () => Printing.sharePdf(bytes: bytes, filename: file.path.split('\\').last)),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error PDF: $e'), backgroundColor: OmniTheme.red400));
    }
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
