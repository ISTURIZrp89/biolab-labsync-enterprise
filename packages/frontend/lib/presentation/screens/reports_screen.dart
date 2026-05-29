import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/storage_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  bool _exporting = false;

  Future<void> _exportMonthly() async {
    setState(() => _exporting = true);
    try {
      final token = await storageService.getToken();
      final url = await storageService.getServerUrl();
      final res = await http.post(
        Uri.parse('$url/api/export/monthly?year=$_year&month=$_month'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Exportacion completada'), backgroundColor: Colors.green),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al exportar'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _exporting = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DropdownButton<int>(
                  value: _month,
                  items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                  onChanged: (v) => setState(() => _month = v!),
                ),
                const SizedBox(width: 16),
                DropdownButton<int>(
                  value: _year,
                  items: List.generate(5, (i) => DropdownMenuItem(value: _year - 2 + i, child: Text('${_year - 2 + i}'))),
                  onChanged: (v) => setState(() => _year = v!),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exporting ? null : _exportMonthly,
                icon: _exporting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download),
                label: Text(_exporting ? 'Exportando...' : 'Exportar mes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
