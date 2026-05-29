import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/storage_service.dart';

class FormEntryScreen extends StatefulWidget {
  final String? module;
  final String? date;

  const FormEntryScreen({super.key, this.module, this.date});

  @override
  State<FormEntryScreen> createState() => _FormEntryScreenState();
}

class _FormEntryScreenState extends State<FormEntryScreen> {
  Map<String, dynamic>? _template;
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadTemplate();
  }

  Future<void> _loadTemplate() async {
    setState(() => _loading = true);
    try {
      final token = await storageService.getToken();
      final url = await storageService.getServerUrl();
      final module = widget.module ?? 'incubadoras';
      final res = await http.get(
        Uri.parse('$url/api/templates/tpl-$module'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _template = jsonDecode(res.body);
        final fields = (_template!['fields'] as List?) ?? [];
        for (final f in fields) {
          final key = f['key'] as String;
          _controllers[key] = TextEditingController();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final token = await storageService.getToken();
      final userId = await storageService.getUserId();
      final deviceId = await storageService.getDeviceId();
      final url = await storageService.getServerUrl();
      final dateStr = widget.date ?? DateTime.now().toIso8601String().split('T')[0];

      final data = <String, dynamic>{};
      for (final entry in _controllers.entries) {
        data[entry.key] = entry.value.text;
      }

      final res = await http.post(
        Uri.parse('$url/api/form-entries'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'id': 'fe-${dateStr}-${DateTime.now().millisecondsSinceEpoch}',
          'module': widget.module ?? _template?['module'] ?? 'incubadoras',
          'date': dateStr,
          'user_id': userId,
          'device_id': deviceId,
          'data': data,
          'status': 'saved',
        }),
      );

      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registro guardado'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_template?['name'] ?? 'Nuevo registro')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _template == null
              ? const Center(child: Text('Plantilla no encontrada'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ...((_template!['fields'] as List?) ?? []).map((f) {
                      final key = f['key'] as String;
                      final label = f['label'] as String;
                      final type = f['type'] as String;
                      final required = f['required'] == true;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _controllers[key],
                          decoration: InputDecoration(
                            labelText: '$label${required ? ' *' : ''}',
                            border: const OutlineInputBorder(),
                          ),
                          keyboardType: type == 'number'
                              ? const TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'Guardando...' : 'Guardar registro'),
                      ),
                    ),
                  ],
                ),
    );
  }
}
