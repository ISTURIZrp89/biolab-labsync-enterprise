import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/db.dart';
import '../../data/csv_mappings.dart';
import '../../theme/omni_theme.dart';

class CsvImportScreen extends StatefulWidget {
  const CsvImportScreen({super.key});

  @override
  State<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends State<CsvImportScreen> {
  List<String> _headers = [];
  List<List<String>> _rows = [];
  Map<String, CsvFieldMapping> _mappings = {};
  String? _selectedFile;
  String _detectedModule = '';
  bool _importing = false;

  final _moduleOptions = [
    'equipos/potenciometro',
    'equipos/condiciones_ambientales',
    'equipos/campanas_flujo_laminar',
    'equipos/centrifugadoras',
    'equipos/microscopio',
    'procesamiento/cajas_exosomas',
  ];

  String _formatModule(String key) {
    final parts = key.split('/');
    if (parts.length != 2) return key;
    final labels = {
      'equipos/potenciometro': 'Equipos > Potenciometro',
      'equipos/condiciones_ambientales': 'Equipos > Condiciones Ambientales',
      'equipos/campanas_flujo_laminar': 'Equipos > Campanas Flujo Laminar',
      'equipos/centrifugadoras': 'Equipos > Centrifugadoras',
      'equipos/microscopio': 'Equipos > Microscopio',
      'procesamiento/cajas_exosomas': 'Procesamiento > Cajas y Exosomas',
    };
    return labels[key] ?? key;
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final lines = content.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;

    final headers = parseCsvLine(lines[0]);
    final rows = lines.skip(1).map(parseCsvLine).toList();
    final mappings = detectModule(headers);
    final detected = detectBestModule(headers);

    setState(() {
      _selectedFile = result.files.single.name;
      _headers = headers;
      _rows = rows;
      _mappings = mappings;
      _detectedModule = detected ?? (_moduleOptions.isNotEmpty ? _moduleOptions[0] : '');
    });
  }

  void _changeModule(String? moduleKey) {
    if (moduleKey == null) return;
    final parts = moduleKey.split('/');
    if (parts.length != 2) return;

    final detector = csvModuleDetectors.firstWhere(
      (d) => d.moduleKey == parts[0] && d.sectionKey == parts[1],
      orElse: () => csvModuleDetectors.first,
    );

    final mappings = <String, CsvFieldMapping>{};
    for (final header in _headers) {
      final trimmed = header.trim();
      for (final mapping in detector.mappings) {
        try {
          if (RegExp(mapping.columnPattern).hasMatch(trimmed)) {
            mappings[trimmed] = mapping;
            break;
          }
        } catch (_) {}
      }
    }

    setState(() {
      _detectedModule = moduleKey;
      _mappings = mappings;
    });
  }

  Future<void> _importData() async {
    if (_rows.isEmpty) return;
    setState(() => _importing = true);

    final parts = _detectedModule.split('/');
    final module = parts[0];
    final section = parts.length > 1 ? parts[1] : '';

    try {
      final db = await LocalDatabase.instance.database;
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? 'csv-import';
      final now = DateTime.now().toUtc().toIso8601String();
      int imported = 0;
      int skipped = 0;

      for (final row in _rows) {
        final data = <String, dynamic>{};
        bool hasAnyData = false;

        for (int i = 0; i < _headers.length && i < row.length; i++) {
          final mapping = _mappings[_headers[i].trim()];
          final value = row[i].trim();
          if (mapping != null && value.isNotEmpty) {
            data[mapping.fieldKey] = value;
            hasAnyData = true;
          }
        }

        if (!hasAnyData) {
          skipped++;
          continue;
        }

        final date = data['fecha']?.toString() ?? now.substring(0, 10);
        final id = 'csv-${DateTime.now().microsecondsSinceEpoch}-$imported';

        await db.insert('form_entries', {
          'id': id,
          'module': module,
          'sub_module': section,
          'date': date,
          'user_id': 'csv-import',
          'device_id': deviceId,
          'version': 1,
          'data_json': jsonEncode(data),
          'status': 'saved',
          'created_at': now,
          'updated_at': now,
        });
        imported++;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Importacion completada: $imported registros${skipped > 0 ? ", $skipped omitidos" : ""}'),
            backgroundColor: OmniTheme.green400,
          ),
        );
        setState(() {
          _selectedFile = null;
          _headers = [];
          _rows = [];
          _mappings = {};
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al importar: $e'), backgroundColor: OmniTheme.red400),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar CSV'),
        backgroundColor: OmniTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [OmniTheme.bg950, OmniTheme.bg900]),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildFilePicker(),
            const SizedBox(height: 16),
            if (_headers.isNotEmpty) ...[
              _buildModuleSelector(),
              const SizedBox(height: 16),
              _buildColumnMapping(),
              const SizedBox(height: 16),
              _buildPreview(),
              const SizedBox(height: 16),
              _buildImportButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.file_upload, size: 48, color: OmniTheme.accentBlue.withOpacity(0.7)),
            const SizedBox(height: 12),
            Text(_selectedFile ?? 'Selecciona un archivo CSV', style: const TextStyle(color: OmniTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _importing ? null : _pickFile,
              icon: const Icon(Icons.folder_open),
              label: const Text('Seleccionar CSV'),
              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Modulo destino', style: TextStyle(color: OmniTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _moduleOptions.contains(_detectedModule) ? _detectedModule : null,
              items: _moduleOptions.map((m) => DropdownMenuItem(value: m, child: Text(_formatModule(m), style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: _changeModule,
              dropdownColor: OmniTheme.bg800,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            if (_detectedModule.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Auto-detectado', style: TextStyle(color: OmniTheme.green400, fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColumnMapping() {
    final parts = _detectedModule.split('/');
    final module = parts.isNotEmpty ? parts[0] : '';
    final section = parts.length > 1 ? parts[1] : '';

    final fields = <Map<String, String>>[];
    if (module.isNotEmpty) {
      for (final detector in csvModuleDetectors) {
        if (detector.moduleKey != module || detector.sectionKey != section) continue;
        for (final mapping in detector.mappings) {
          final matchedHeader = _headers.cast<String?>().firstWhere(
            (h) => h != null && _mappings[h]?.fieldKey == mapping.fieldKey,
            orElse: () => null,
          );
          fields.add({
            'fieldKey': mapping.fieldKey,
            'fieldLabel': _getFieldLabel(mapping.columnPattern),
            'matchedHeader': matchedHeader ?? '(sin mapeo)',
            'matched': matchedHeader != null ? 'Si' : 'No',
          });
        }
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mapeo de columnas', style: TextStyle(color: OmniTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...fields.map((f) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(f['fieldLabel'] ?? '', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 12)),
                  ),
                  const Icon(Icons.arrow_forward, size: 12, color: OmniTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(f['matchedHeader'] ?? '', style: TextStyle(color: f['matched'] == 'Si' ? OmniTheme.green400 : OmniTheme.red400, fontSize: 12)),
                  ),
                  if (f['matched'] == 'Si')
                    const Icon(Icons.check_circle, size: 14, color: OmniTheme.green400)
                  else
                    const Icon(Icons.cancel, size: 14, color: OmniTheme.red400),
                ],
              ),
            )),
            const SizedBox(height: 8),
            Text('Coincidencia: ${_mappings.length}/${_headers.length} columnas', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  String _getFieldLabel(String pattern) {
    return pattern.replaceAll(RegExp(r'\(\?i\)|\\|\.\*|\^|\$'), '');
  }

  Widget _buildPreview() {
    final previewRows = _rows.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Vista previa (${_rows.length} filas)', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(OmniTheme.bg800),
                dataRowColor: WidgetStateProperty.all(OmniTheme.bg900),
                columns: _headers.map((h) => DataColumn(label: Text(h, style: const TextStyle(color: OmniTheme.accentBlue, fontSize: 11)))).toList(),
                rows: previewRows.map((row) => DataRow(
                  cells: List.generate(_headers.length, (i) => DataCell(
                    Text(i < row.length ? row[i] : '', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 11), overflow: TextOverflow.ellipsis),
                  )),
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportButton() {
    return ElevatedButton.icon(
      onPressed: _importing || _rows.isEmpty ? null : _importData,
      icon: _importing
        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.publish),
      label: Text(_importing ? 'Importando...' : 'Importar ${_rows.length} registros'),
      style: ElevatedButton.styleFrom(
        backgroundColor: OmniTheme.green400,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}
