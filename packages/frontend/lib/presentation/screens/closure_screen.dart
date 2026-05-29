import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../core/storage_service.dart';

class ClosureScreen extends StatefulWidget {
  const ClosureScreen({super.key});

  @override
  State<ClosureScreen> createState() => _ClosureScreenState();
}

class _ClosureScreenState extends State<ClosureScreen> {
  DateTime _selectedDate = DateTime.now();
  Map<String, dynamic>? _dayStatus;
  Map<String, dynamic>? _monthStatus;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);
    try {
      final token = await storageService.getToken();
      final url = await storageService.getServerUrl();
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final dayRes = await http.get(
        Uri.parse('$url/api/calendar/day/$dateStr'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (dayRes.statusCode == 200) {
        _dayStatus = jsonDecode(dayRes.body);
      }
      final mRes = await http.get(
        Uri.parse('$url/api/calendar/month-status/${_selectedDate.year}/${_selectedDate.month}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (mRes.statusCode == 200) {
        _monthStatus = jsonDecode(mRes.body);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _closeDay() async {
    final token = await storageService.getToken();
    final url = await storageService.getServerUrl();
    final userId = await storageService.getUserId();
    final dateStr = _selectedDate.toIso8601String().split('T')[0];
    await http.post(
      Uri.parse('$url/api/calendar/close-day'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'date': dateStr, 'status': 'CERRADO', 'closed_by': userId}),
    );
    _loadStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cierres')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                        _loadStatus();
                      }
                    },
                    icon: const Icon(Icons.calendar_month),
                    label: Text(_selectedDate.toIso8601String().split('T')[0]),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: ListTile(
                      title: const Text('Estado del dia'),
                      trailing: Text(_dayStatus?['closure_status'] ?? 'ABIERTO'),
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Estado del mes'),
                      trailing: Text(_monthStatus?['status'] ?? 'ABIERTO'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _closeDay,
                    icon: const Icon(Icons.lock),
                    label: const Text('Cerrar dia'),
                  ),
                ],
              ),
            ),
    );
  }
}
