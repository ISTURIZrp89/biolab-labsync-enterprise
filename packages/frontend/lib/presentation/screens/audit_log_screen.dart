import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
      final response = await http.get(
        Uri.parse('$serverUrl/api/audit'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _logs = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  IconData _iconForAction(String action) {
    switch (action) {
      case 'LOGIN':
      case 'LOGIN_FAILED':
        return Icons.login;
      case 'CLOSE_DAY':
      case 'CLOSE_MONTH':
        return Icons.lock;
      case 'REOPEN_DAY':
      case 'REOPEN_MONTH':
        return Icons.lock_open;
      case 'SYNC':
        return Icons.sync;
      case 'CREATE_USER':
      case 'UPDATE_USER':
      case 'DELETE_USER':
        return Icons.person;
      case 'SYNC_CONFLICT_RESOLVED':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Auditoria')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(child: Text('Sin registros de auditoria'))
              : ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (_, i) {
                    final log = _logs[i];
                    return ListTile(
                      leading: Icon(_iconForAction(log['action'] ?? '')),
                      title: Text(log['action'] ?? ''),
                      subtitle: Text(log['timestamp'] ?? ''),
                      trailing: Text(log['user_id'] ?? ''),
                    );
                  },
                ),
    );
  }
}
