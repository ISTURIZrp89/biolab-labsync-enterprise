import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final _backupService = BackupService();
  String _status = '';

  Future<void> _exportBackup() async {
    setState(() => _status = 'Exportando...');
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('backup_path') ?? '.';
    final result = await _backupService.exportBackup(path);
    setState(() => _status = result ?? 'Error al exportar');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Respaldo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exporta la base de datos local como respaldo.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _exportBackup,
                icon: const Icon(Icons.backup),
                label: const Text('Exportar respaldo'),
              ),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Text(_status, style: const TextStyle(color: Colors.green)),
          ],
        ),
      ),
    );
  }
}
