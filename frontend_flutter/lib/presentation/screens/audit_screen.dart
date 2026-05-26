import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/db.dart';
import '../../theme/omni_theme.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _loading = true);
    final db = await LocalDatabase.instance.database;
    final logs = await db.query(
      'audit_log',
      orderBy: 'timestamp DESC',
      limit: 200,
    );
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      return DateFormat('dd/MM/yyyy HH:mm', 'es').format(date);
    } catch (_) {
      return timestamp;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action.toUpperCase()) {
      case 'LOGIN':
        return Icons.login;
      case 'LOGOUT':
        return Icons.logout;
      case 'SYNC':
        return Icons.sync;
      case 'CLOSE_DAY':
        return Icons.lock;
      case 'REOPEN_DAY':
        return Icons.lock_open;
      case 'CREATE':
      case 'UPDATE':
        return Icons.edit;
      case 'DELETE':
        return Icons.delete;
      default:
        return Icons.info;
    }
  }

  Color _getActionColor(String action) {
    switch (action.toUpperCase()) {
      case 'LOGIN':
        return Colors.green;
      case 'LOGOUT':
        return Colors.grey;
      case 'SYNC':
        return Colors.blue;
      case 'CLOSE_DAY':
        return Colors.orange;
      case 'REOPEN_DAY':
        return Colors.red;
      case 'CREATE':
        return Colors.greenAccent;
      case 'UPDATE':
        return Colors.blueAccent;
      case 'DELETE':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final action = log['action'] as String;
    final userId = log['user_id'] as String? ?? 'Sistema';
    final deviceId = log['device_id'] as String? ?? '';
    final timestamp = log['timestamp'] as String;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: OmniTheme.bg950,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getActionColor(action).withOpacity(0.2),
          child: Icon(
            _getActionIcon(action),
            color: _getActionColor(action),
            size: 20,
          ),
        ),
        title: Text(
          action,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Usuario: $userId',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            ),
            if (deviceId.isNotEmpty)
              Text(
                'Device: ${deviceId.substring(0, deviceId.length > 8 ? 8 : deviceId.length)}...',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              ),
          ],
        ),
        trailing: Text(
          _formatTimestamp(timestamp),
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditoria'),
        backgroundColor: OmniTheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLogs,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001020), Color(0xFF000810)],
          ),
        ),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'Sin registros de auditoria',
              style: TextStyle(color: Colors.white.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        return _buildLogItem(_logs[index]);
      },
    );
  }
}
