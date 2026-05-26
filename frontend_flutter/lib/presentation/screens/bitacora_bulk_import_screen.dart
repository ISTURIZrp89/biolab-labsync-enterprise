import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../data/csv_mappings.dart';
import '../../theme/omni_theme.dart';

class BitacoraBulkImportScreen extends StatefulWidget {
  const BitacoraBulkImportScreen({super.key});

  @override
  State<BitacoraBulkImportScreen> createState() => _BitacoraBulkImportScreenState();
}

class _BitacoraBulkImportScreenState extends State<BitacoraBulkImportScreen> {
  List<String> _headers = [];
  List<List<String>> _rows = [];
  Map<String, String> _columnMapping = {};
  String? _selectedFile;
  bool _loading = false;
  bool _imported = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (result == null || result.files.isEmpty) return;
    setState(() => _loading = true);
    try {
      final file = File(result.files.single.path!);
      final lines = await file.readAsLines();
      if (lines.isEmpty) throw Exception('Archivo vacio');
      _headers = parseCsvLine(lines[0]);
      _rows = lines.skip(1).map(parseCsvLine).where((r) => r.length == _headers.length && r.any((v) => v.trim().isNotEmpty)).toList();
      _selectedFile = result.files.single.name;
      await _autoMapColumns();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OmniTheme.red400));
      }
    }
  }

  Future<void> _autoMapColumns() async {
    final mappings = detectModule(_headers);
    _columnMapping = {};
    for (final header in _headers) {
      final mapping = mappings[header.trim()];
      if (mapping != null) {
        _columnMapping[header.trim()] = mapping.fieldKey;
      }
    }
    for (final header in _headers) {
      if (!_columnMapping.containsKey(header.trim())) {
        final h = header.trim().toLowerCase();
        if (h.contains('fecha')) _columnMapping[header.trim()] = 'fecha';
        else if (h.contains('actividad')) _columnMapping[header.trim()] = 'actividad';
        else if (h.contains('caja')) _columnMapping[header.trim()] = 'cajas';
        else if (h.contains('tejido')) _columnMapping[header.trim()] = 'tipo_tejido';
        else if (h.contains('vial')) _columnMapping[header.trim()] = 'viales';
        else if (h.contains('observ')) _columnMapping[header.trim()] = 'observaciones';
        else if (h.contains('misid')) _columnMapping[header.trim()] = 'misid';
        else if (h.contains('mill')) _columnMapping[header.trim()] = 'millones';
        else if (h.contains('responsable') || h.contains('nombre')) _columnMapping[header.trim()] = 'responsable';
        else if (h.contains('descrip')) _columnMapping[header.trim()] = 'descripcion';
        else _columnMapping[header.trim()] = '';
      }
    }
  }

  Future<void> _importAsPending() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList('pending_bitacora_imports') ?? [];
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      for (int i = 0; i < _rows.length; i++) {
        final row = _rows[i];
        final entry = <String, dynamic>{};
        for (int c = 0; c < _headers.length; c++) {
          final fieldKey = _columnMapping[_headers[c]] ?? '';
          if (fieldKey.isNotEmpty) {
            entry[fieldKey] = row[c].trim();
          }
        }
        entry['_import_id'] = '${dateStr}_$i';
        entry['_import_date'] = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
        entry['_approval_status'] = 'pending';
        existing.add(jsonEncode(entry));
      }

      await prefs.setStringList('pending_bitacora_imports', existing);
      if (mounted) {
        setState(() { _imported = true; _loading = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${_rows.length} entrada(s) importadas. Admin debe aprobarlas en Ajustes.'),
          backgroundColor: OmniTheme.green400,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: OmniTheme.red400));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Importar Bitacoras Anteriores', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        backgroundColor: OmniTheme.bg900, elevation: 0,
        actions: [
          if (_rows.isNotEmpty && !_imported)
            IconButton(
              icon: _loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_alt, color: OmniTheme.green400),
              tooltip: 'Importar como pendientes',
              onPressed: _loading ? null : _importAsPending,
            ),
        ],
      ),
      body: _loading && _rows.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_selectedFile == null)
                  Expanded(child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.upload_file, size: 64, color: OmniTheme.bg700),
                      const SizedBox(height: 16),
                      const Text('Selecciona un archivo CSV', style: TextStyle(color: OmniTheme.textMuted, fontSize: 14)),
                      const SizedBox(height: 8),
                      const Text('con datos de bitacora de meses anteriores', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.folder_open, size: 18),
                        label: const Text('Seleccionar archivo CSV'),
                        onPressed: _pickFile,
                        style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
                      ),
                    ]),
                  ))
                else
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: OmniTheme.bg900,
                          child: Row(children: [
                            const Icon(Icons.insert_drive_file, size: 16, color: OmniTheme.accentBlue),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_selectedFile!, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 12))),
                            Text('${_rows.length} filas', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 16, color: OmniTheme.textMuted),
                              onPressed: _pickFile,
                              tooltip: 'Cambiar archivo',
                            ),
                          ]),
                        ),
                        if (_columnMapping.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(8),
                            color: OmniTheme.bg900.withOpacity(0.5),
                            child: Wrap(
                              spacing: 8, runSpacing: 4,
                              children: _columnMapping.entries.where((e) => e.value.isNotEmpty).map((e) =>
                                Chip(
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  label: Text('${e.key} → ${e.value}', style: const TextStyle(fontSize: 9, color: OmniTheme.accentBlue)),
                                  backgroundColor: OmniTheme.accentBlue.withOpacity(0.1),
                                  side: BorderSide.none,
                                ),
                              ).toList(),
                            ),
                          ),
                        ],
                        Expanded(
                          child: _headers.isEmpty
                              ? const Center(child: Text('Sin datos', style: TextStyle(color: OmniTheme.textMuted)))
                              : SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      headingRowColor: WidgetStateProperty.all(OmniTheme.bg800),
                                      dataRowMinHeight: 28,
                                      dataRowMaxHeight: 36,
                                      columns: _headers.map((h) => DataColumn(
                                        label: Text(h, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: OmniTheme.textMuted)),
                                      )).toList(),
                                      rows: _rows.map((r) => DataRow(
                                        cells: r.map((v) => DataCell(
                                          SizedBox(
                                            width: 120,
                                            child: Text(v, style: const TextStyle(fontSize: 10, color: OmniTheme.textPrimary), overflow: TextOverflow.ellipsis),
                                          ),
                                        )).toList(),
                                      )).toList(),
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                if (_imported)
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: OmniTheme.green400.withOpacity(0.1),
                    child: Row(children: [
                      const Icon(Icons.check_circle, color: OmniTheme.green400, size: 20),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${_rows.length} entrada(s) importadas. Ve a "Aprobar Importaciones Pendientes" en Ajustes.', style: const TextStyle(color: OmniTheme.green400, fontSize: 12))),
                    ]),
                  ),
              ],
            ),
    );
  }
}
