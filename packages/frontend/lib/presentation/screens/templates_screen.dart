import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/storage_service.dart';

class TemplatesScreen extends StatefulWidget {
  const TemplatesScreen({super.key});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen> {
  List<Map<String, dynamic>> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    try {
      final token = await storageService.getToken();
      final url = await storageService.getServerUrl();
      final res = await http.get(
        Uri.parse('$url/api/templates'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _templates = (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _templates.isEmpty
              ? const Center(child: Text('Sin plantillas'))
              : ListView.builder(
                  itemCount: _templates.length,
                  itemBuilder: (_, i) {
                    final t = _templates[i];
                    final fields = (t['fields'] as List?) ?? [];
                    return ExpansionTile(
                      title: Text(t['name'] ?? ''),
                      subtitle: Text(t['module'] ?? ''),
                      children: fields.map((f) {
                        return ListTile(
                          dense: true,
                          title: Text(f['label'] ?? ''),
                          subtitle: Text('${f['type']}${f['required'] == true ? ' *' : ''}'),
                          trailing: Icon(f['required'] == true ? Icons.star : Icons.star_border, size: 16),
                        );
                      }).toList(),
                    );
                  },
                ),
    );
  }
}
