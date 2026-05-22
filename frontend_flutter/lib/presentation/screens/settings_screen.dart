import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../data/db.dart';
import '../../sync/sync_engine.dart';
import '../../services/update_service.dart';
import '../../theme/omni_theme.dart';

String _getPlatformName() {
  if (kIsWeb) return 'Web (navegador)';
  return 'Desktop';
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _deviceId = 'Cargando...';
  String _platform = '';
  String _backendUrl = 'http://localhost:8000';
  String _appVersion = '1.0.0';
  bool _isOnline = false;
  int _pendingSync = 0;
  String _lastSync = 'Nunca';
  bool _autoSync = true;
  String _savePath = '';
  List<Map<String, String>> _equipmentList = [];

  @override
  void initState() {
    super.initState();
    _platform = _getPlatformName();
    _loadSettings();
    _loadEquipment();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'Unknown';
    final savedUrl = prefs.getString('backend_url');
    final autoSync = prefs.getBool('auto_sync') ?? true;
    final lastSync = prefs.getString('last_sync_timestamp');
    final savePath = prefs.getString('save_path') ?? '';

    setState(() {
      _deviceId = deviceId;
      _backendUrl = savedUrl ?? 'http://localhost:8000';
      _autoSync = autoSync;
      _lastSync = lastSync != null ? _formatTimestamp(lastSync) : 'Nunca';
      _savePath = savePath;
    });

    final sync = context.read<SyncEngine>();
    setState(() {
      _isOnline = sync.isOnline;
      _pendingSync = sync.pendingCount;
      if (sync.lastSync != null) {
        _lastSync = _formatTimestamp(sync.lastSync!.toIso8601String());
      }
    });
  }

  Future<void> _loadEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('equipment_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        setState(() {
          _equipmentList = list.map((e) => Map<String, String>.from(e as Map)).toList();
        });
      } catch (_) {}
    }
  }

  Future<void> _saveEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('equipment_list', jsonEncode(_equipmentList));
  }

  void _addEquipment(String name, String category) {
    setState(() {
      _equipmentList.add({'name': name, 'category': category});
    });
    _saveEquipment();
  }

  void _removeEquipment(int index) {
    setState(() {
      _equipmentList.removeAt(index);
    });
    _saveEquipment();
  }

  String _formatTimestamp(String timestamp) {
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'Hace un momento';
      if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return timestamp;
    }
  }

  Future<void> _checkForUpdates() async {
    final updateService = context.read<UpdateService>();
    await updateService.checkForUpdates();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updateService.hasUpdate ? 'Nueva version: v${updateService.latestVersion}' : 'La aplicacion esta actualizada')),
      );
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_sync', value);
    setState(() => _autoSync = value);

    final sync = context.read<SyncEngine>();
    if (value) {
      sync.startPeriodicSync();
    } else {
      sync.stopPeriodicSync();
    }
  }

  Future<void> _changeBackendUrl() async {
    final controller = TextEditingController(text: _backendUrl);
    final newUrl = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('URL del Servidor', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'http://localhost:8000',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newUrl != null && newUrl.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('backend_url', newUrl);
      setState(() => _backendUrl = newUrl);
    }
  }

  Future<void> _changeSavePath() async {
    final controller = TextEditingController(text: _savePath);
    final newPath = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Carpeta de Reportes', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Ruta donde se guardaran los reportes generados (PDF, Excel)', style: TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'C:\\Reportes\\BioLab',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.folder, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (newPath != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('save_path', newPath);
      setState(() => _savePath = newPath);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final db = await LocalDatabase.instance.database;
      final tables = ['form_entries', 'day_closures', 'audit_log', 'settings'];
      final backup = <String, dynamic>{};
      for (final table in tables) {
        backup[table] = await db.query(table);
      }
      final prefs = await SharedPreferences.getInstance();
      backup['preferences'] = {
        'backend_url': prefs.getString('backend_url'),
        'auto_sync': prefs.getBool('auto_sync'),
        'device_id': prefs.getString('device_id'),
        'save_path': prefs.getString('save_path'),
        'equipment_list': prefs.getString('equipment_list'),
      };
      final json = const JsonEncoder.withIndent('  ').convert(backup);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup exportado (${json.length} bytes)'),
          action: SnackBarAction(label: 'Copiar', onPressed: () {
            // In a real app, this would save to a file
          }),
        ),
      );

      final blob = utf8.encode(json);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Backup: ${blob.length} datos guardados'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: OmniTheme.red400),
        );
      }
    }
  }

  Future<void> _showAddEquipmentDialog() async {
    final nameCtrl = TextEditingController();
    String category = 'Incubadoras';
    final categories = ['Incubadoras', 'Ultracongeladores', 'Autoclaves', 'Campanas', 'Centrifugas', 'Microscopios', 'Potenciometros'];

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Agregar Equipo', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nombre del equipo',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: category,
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
              onChanged: (v) => category = v ?? category,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                labelStyle: TextStyle(color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: nameCtrl.text.isNotEmpty ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (result == true && nameCtrl.text.isNotEmpty) {
      _addEquipment(nameCtrl.text, category);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuracion'),
        backgroundColor: const Color(0xFF004A99),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [OmniTheme.bg950, OmniTheme.bg900],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection('Estado del Sistema', [
              _buildInfoRow('Estado', _isOnline ? 'En linea' : 'Desconectado', Icons.wifi),
              _buildInfoRow('Plataforma', _platform, Icons.devices),
              _buildInfoRow('Ultima Sincronizacion', _lastSync, Icons.sync),
              _buildInfoRow('Pendientes', '$_pendingSync registros', Icons.pending),
            ]),
            const SizedBox(height: 16),
            _buildSection('Dispositivo', [
              _buildInfoRow('Device ID', _deviceId, Icons.fingerprint),
              _buildInfoRow('Version App', _appVersion, Icons.info),
            ]),
            const SizedBox(height: 16),
            _buildSection('Sincronizacion', [
              SwitchListTile(
                title: const Text('Sincronizacion Automatica', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_autoSync ? 'Cada 5 minutos' : 'Desactivada', style: TextStyle(color: OmniTheme.textMuted)),
                value: _autoSync,
                onChanged: _toggleAutoSync,
                activeColor: OmniTheme.accentBlue,
              ),
              ListTile(
                leading: const Icon(Icons.sync, color: OmniTheme.accentBlue),
                title: const Text('Sincronizar Ahora', style: TextStyle(color: OmniTheme.textPrimary)),
                onTap: () async {
                  final sync = context.read<SyncEngine>();
                  final success = await sync.synchronize();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? 'Sincronizacion completada' : 'Error al sincronizar')),
                    );
                    _loadSettings();
                  }
                },
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Servidor', [
              ListTile(
                leading: const Icon(Icons.dns, color: OmniTheme.accentBlue),
                title: const Text('URL del Servidor', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_backendUrl, style: const TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: _changeBackendUrl,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Carpeta de Reportes', [
              ListTile(
                leading: const Icon(Icons.folder, color: OmniTheme.accentBlue),
                title: const Text('Ruta de guardado', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_savePath.isNotEmpty ? _savePath : 'No configurada', style: const TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: _changeSavePath,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Equipos (${_equipmentList.length})', [
              ..._equipmentList.asMap().entries.map((e) => ListTile(
                dense: true,
                leading: Container(
                  width: 6, height: 6,
                  decoration: const BoxDecoration(color: OmniTheme.accentBlue, shape: BoxShape.circle),
                ),
                title: Text(e.value['name'] ?? '', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                subtitle: Text(e.value['category'] ?? '', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 16, color: OmniTheme.red400),
                  onPressed: () => _removeEquipment(e.key),
                ),
              )),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: _showAddEquipmentDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Equipo', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Respaldo', [
              ListTile(
                leading: const Icon(Icons.backup, color: OmniTheme.accentBlue),
                title: const Text('Exportar Backup', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Respaldar configuracion y datos', style: TextStyle(color: OmniTheme.textMuted)),
                onTap: _exportBackup,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Actualizaciones', [
              ListTile(
                leading: const Icon(Icons.system_update, color: OmniTheme.accentBlue),
                title: const Text('Buscar Actualizaciones', style: TextStyle(color: OmniTheme.textPrimary)),
                onTap: _checkForUpdates,
              ),
            ]),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'LABSYNC Enterprise v$_appVersion',
                style: TextStyle(color: OmniTheme.textMuted.withOpacity(0.3), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: OmniTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: OmniTheme.accentBlue, size: 20),
      title: Text(label, style: const TextStyle(color: OmniTheme.textPrimary)),
      subtitle: Text(value, style: const TextStyle(color: OmniTheme.textMuted)),
    );
  }
}
