import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/ai_import_service.dart';
import '../../theme/omni_theme.dart';
import 'pending_import_approval_screen.dart';

class AiImportScreen extends StatefulWidget {
  const AiImportScreen({super.key});

  @override
  State<AiImportScreen> createState() => _AiImportScreenState();
}

class _AiImportScreenState extends State<AiImportScreen> {
  final _service = AiImportService();
  String? _filePath;
  String? _fileName;
  String _extractedText = '';
  List<Map<String, dynamic>> _parsedEntries = [];
  bool _extracting = false;
  bool _parsing = false;
  bool _saving = false;
  String _status = '';
  String? _error;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'xlsx', 'xls', 'docx', 'txt', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _filePath = result.files.single.path;
      _fileName = result.files.single.name;
      _extractedText = '';
      _parsedEntries = [];
      _error = null;
      _status = 'Archivo seleccionado: $_fileName';
    });
  }

  Future<void> _extractAndParse() async {
    if (_filePath == null) return;
    setState(() {
      _extracting = true;
      _parsing = true;
      _error = null;
      _status = 'Extrayendo texto...';
    });

    try {
      final text = await _service.extractText(_filePath!);
      setState(() {
        _extractedText = text;
        _extracting = false;
        _status = 'Texto extraido (${text.length} caracteres). Enviando a IA...';
      });

      final result = await _service.parseWithAi(text);
      setState(() {
        _parsing = false;
        if (result.success) {
          _parsedEntries = result.entries;
          _status = 'IA encontro ${result.entries.length} entradas';
        } else {
          _error = result.error;
          _status = 'Error de IA';
        }
      });
    } catch (e) {
      setState(() {
        _extracting = false;
        _parsing = false;
        _error = 'Error: $e';
        _status = 'Error';
      });
    }
  }

  Future<void> _saveToPending() async {
    if (_parsedEntries.isEmpty) return;
    setState(() {
      _saving = true;
      _status = 'Guardando...';
    });

    try {
      final count = await _service.saveToPending(_parsedEntries);
      setState(() {
        _saving = false;
        _status = '$count entradas guardadas para aprobacion';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count entradas enviadas a aprobacion'), backgroundColor: OmniTheme.green400),
        );
      }
    } catch (e) {
      setState(() {
        _saving = false;
        _error = 'Error al guardar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Importar con IA'),
        backgroundColor: OmniTheme.bg900,
        actions: [
          if (_parsedEntries.isNotEmpty)
            TextButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingImportApprovalScreen())),
              icon: const Icon(Icons.checklist, size: 18),
              label: const Text('Aprobar'),
            ),
        ],
      ),
      backgroundColor: OmniTheme.bg900,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFileSection(),
            const SizedBox(height: 16),
            if (_extracting || _parsing) const Center(child: CircularProgressIndicator()),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: OmniTheme.red400.withOpacity(0.1),
                  border: Border.all(color: OmniTheme.red400.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_error!, style: const TextStyle(color: OmniTheme.red400, fontSize: 12)),
              ),
            if (_status.isNotEmpty && _error == null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_status, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
              ),
            if (_parsedEntries.isNotEmpty) ...[
              Row(children: [
                const Text('Entradas detectadas:', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text('${_parsedEntries.length}', style: const TextStyle(color: OmniTheme.accentBlue, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              ..._parsedEntries.map((e) => Card(
                color: OmniTheme.bg800,
                margin: const EdgeInsets.only(bottom: 4),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: e.entries.map((kv) {
                      if (kv.key.startsWith('_')) return const SizedBox.shrink();
                      final val = kv.value?.toString() ?? '';
                      if (val.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Row(
                          children: [
                            SizedBox(width: 100, child: Text('${kv.key}:', style: const TextStyle(fontSize: 10, color: OmniTheme.textMuted))),
                            Expanded(child: Text(val, style: const TextStyle(fontSize: 10, color: OmniTheme.textPrimary))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              )),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _saveToPending,
                  icon: _saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Guardando...' : 'Guardar ${_parsedEntries.length} entradas para aprobacion'),
                ),
              ),
            ],
            if (_extractedText.isNotEmpty && _parsedEntries.isEmpty && !_parsing) ...[
              const SizedBox(height: 16),
              const Text('Texto extraido (vista previa):', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: OmniTheme.bg800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _extractedText.length > 2000 ? '${_extractedText.substring(0, 2000)}...' : _extractedText,
                  style: const TextStyle(fontSize: 9, color: OmniTheme.textMuted, fontFamily: 'monospace'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFileSection() {
    return Card(
      color: OmniTheme.bg800,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Seleccionar archivo', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('PDF, Excel (.xlsx/.xls), Word (.docx), TXT, CSV', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickFile,
                  icon: const Icon(Icons.file_open),
                  label: Text(_fileName ?? 'Elegir archivo...'),
                ),
              ),
            ]),
            if (_filePath != null) ...[
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: (_extracting || _parsing) ? null : _extractAndParse,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Extraer y analizar con IA'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
