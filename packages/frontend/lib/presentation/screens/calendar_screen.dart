import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  Map<String, dynamic>? _monthData;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadMonth();
  }

  Future<void> _loadMonth() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final url = prefs.getString('server_url') ?? 'http://localhost:8000';
      final res = await http.get(
        Uri.parse('$url/api/calendar/month?year=${_currentMonth.year}&month=${_currentMonth.month}'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        _monthData = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Color _colorForStatus(String? status) {
    switch (status) {
      case 'CERRADO':
        return Colors.green;
      case 'REABIERTO':
        return Colors.orange;
      case 'COMPLETO':
        return Colors.blue;
      case 'PENDIENTE':
        return Colors.yellow;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${_currentMonth.year}-${_currentMonth.month.toString().padLeft(2, '0')}'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1));
              _loadMonth();
            },
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            onPressed: () {
              setState(() => _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1));
              _loadMonth();
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _monthData == null
              ? const Center(child: Text('Error al cargar'))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: (_monthData?['days'] as List?)?.length ?? 0,
                  itemBuilder: (_, i) {
                    final day = (_monthData!['days'] as List)[i] as Map<String, dynamic>;
                    final date = day['date']?.toString().split('-').last ?? '';
                    final status = day['closure_status']?.toString() ?? 'ABIERTO';
                    return Card(
                      color: _colorForStatus(status).withOpacity(0.2),
                      child: Center(
                        child: Text(
                          date,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _colorForStatus(status),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
