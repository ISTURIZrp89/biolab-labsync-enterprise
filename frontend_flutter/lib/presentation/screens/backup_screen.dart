import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/backup_service.dart';
import '../../theme/omni_theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> _backups = [];
  bool _loading = true;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final baseDir = prefs.getString('backup_base_dir') ?? '';
    if (baseDir.isEmpty) {
      setState(() {
        _backups = [];
        _loading = false;
        _status = 'Configure una carpeta base para respaldos en Ajustes > Carpeta de Respaldos';
      });
      return;
    }
    final dir = Directory(baseDir);
    if (!await dir.exists()) {
      setState(() {
        _backups = [];
        _loading = false;
        _status = 'La carpeta de respaldos no existe';
      });
      return;
    }
    final files = await dir.list().toList();
    final backups = <Map<String, dynamic>>[];
    final fmt = DateFormat('yyyy-MM-dd HH:mm');
    for (final f in files) {
      if (f is File && f.path.endsWith('.db')) {
        final stat = await f.stat();
        backups.add({
          'path': f.path,
          'name': f.path.split('\\').last.split('/').last,
          'size': stat.size,
          'modified': stat.modified,
          'modifiedStr': fmt.format(stat.modified.toLocal()),
        });
      }
    }
    backups.sort((a, b) => (b['modified'] as DateTime).compareTo(a['modified'] as DateTime));
    setState(() {
      _backups = backups;
      _loading = false;
      _status = backups.isEmpty ? 'No se encontraron respaldos .db' : '';
    });
  }

  Future<void> _restoreBackup(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar Respaldo'),
        content: const Text('Se reemplazara la base de datos actual. Esta accion no se puede deshacer. Desea continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Restaurar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _status = 'Restaurando...');
    try {
      await BackupService().restoreFromFile(path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo restaurado correctamente'), backgroundColor: Colors.green),
        );
        _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _status = 'Error: $e');
      }
    }
  }

  Future<void> _createManualBackup() async {
    setState(() => _status = 'Creando respaldo...');
    try {
      final path = await BackupService().backupManual();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Respaldo creado: $path'), backgroundColor: Colors.green),
        );
        _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importExternalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['db'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = File(result.files.single.path!);
    if (!await file.exists()) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar .db externo'),
        content: Text('Importar ${result.files.single.name} como base de datos? Se reemplazara la actual.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Importar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _status = 'Importando...');
    try {
      await BackupService().restoreFromFile(file.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Base de datos importada correctamente'), backgroundColor: Colors.green),
        );
        _loadBackups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respaldos'),
        backgroundColor: OmniTheme.bgDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar lista',
            onPressed: _loadBackups,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Crear respaldo manual',
            onPressed: _createManualBackup,
          ),
          IconButton(
            icon: const Icon(Icons.file_open),
            tooltip: 'Importar .db externo',
            onPressed: _importExternalFile,
          ),
        ],
      ),
      backgroundColor: OmniTheme.bgDark,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _backups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.backup, size: 64, color: OmniTheme.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(_status, textAlign: TextAlign.center, style: const TextStyle(color: OmniTheme.textMuted)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _createManualBackup,
                          icon: const Icon(Icons.add),
                          label: const Text('Crear primer respaldo'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _importExternalFile,
                          icon: const Icon(Icons.file_open),
                          label: const Text('Importar .db externo'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    if (_status.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(_status, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                      ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _backups.length,
                        itemBuilder: (ctx, i) {
                          final b = _backups[i];
                          return Card(
                            color: OmniTheme.bgCard,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: const Icon(Icons.storage, color: OmniTheme.green400),
                              title: Text(b['name'] as String, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                              subtitle: Text(
                                '${b['modifiedStr']} - ${_formatSize(b['size'] as int)}',
                                style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.restore, size: 20, color: OmniTheme.accentBlue),
                                    tooltip: 'Restaurar',
                                    onPressed: () => _restoreBackup(b['path'] as String),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    tooltip: 'Eliminar',
                                    onPressed: () async {
                                      final f = File(b['path'] as String);
                                      await f.delete();
                                      _loadBackups();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
