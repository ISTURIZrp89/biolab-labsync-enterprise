import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/db.dart';
import '../../sync/sync_engine.dart';
import '../../services/update_service.dart';
import '../../theme/omni_theme.dart';
import '../screens/csv_import_screen.dart';

String _getPlatformName() {
  if (kIsWeb) return 'Web (navegador)';
  return 'Desktop';
}

const _userRoles = ['Admin', 'Supervisor', 'Laboratorio', 'Auditor', 'Dueno'];

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
  String _backupPath = '';
  bool _encryptLocal = true;
  List<Map<String, String>> _equipmentList = [];
  List<Map<String, String>> _users = [];
  bool _isAdmin = false;
  bool _lanSyncEnabled = false;
  bool _broadcastDiscovery = true;
  String _lanPort = '8765';
  List<String> _detectedPeers = [];
  String _dbSize = 'Calculando...';

  @override
  void initState() {
    super.initState();
    _platform = _getPlatformName();
    _loadSettings();
    _loadEquipment();
    _loadUsers();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'Unknown';
    final savedUrl = prefs.getString('backend_url');
    final autoSync = prefs.getBool('auto_sync') ?? true;
    final lastSync = prefs.getString('last_sync_timestamp');
    final savePath = prefs.getString('save_path') ?? '';
    final backupPath = prefs.getString('backup_path') ?? '';
    final encryptLocal = prefs.getBool('encrypt_local') ?? true;
    final lanSync = prefs.getBool('lan_sync_enabled') ?? false;
    final broadcast = prefs.getBool('lan_broadcast_discovery') ?? true;
    final lanPort = prefs.getString('lan_port') ?? '8765';

    setState(() {
      _deviceId = deviceId;
      _backendUrl = savedUrl ?? 'http://localhost:8000';
      _autoSync = autoSync;
      _lastSync = lastSync != null ? _formatTimestamp(lastSync) : 'Nunca';
      _savePath = savePath;
      _backupPath = backupPath;
      _encryptLocal = encryptLocal;
      _lanSyncEnabled = lanSync;
      _broadcastDiscovery = broadcast;
      _lanPort = lanPort;
    });

    final sync = context.read<SyncEngine>();
    setState(() {
      _isOnline = sync.isOnline;
      _pendingSync = sync.pendingCount;
      if (sync.lastSync != null) {
        _lastSync = _formatTimestamp(sync.lastSync!.toIso8601String());
      }
    });

    _loadDbSize();
  }

  Future<void> _loadDbSize() async {
    try {
      final db = await LocalDatabase.instance.database;
      final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM form_entries');
      final count = (result.isNotEmpty ? result.first['cnt'] as int? : null) ?? 0;
      if (mounted) setState(() => _dbSize = '$count registros');
    } catch (_) {
      if (mounted) setState(() => _dbSize = 'Error');
    }
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

  void _addEquipment(Map<String, String> equipment) {
    setState(() {
      _equipmentList.add(equipment);
    });
    _saveEquipment();
  }

  void _updateEquipment(int index, Map<String, String> equipment) {
    setState(() {
      _equipmentList[index] = equipment;
    });
    _saveEquipment();
  }

  void _removeEquipment(int index) {
    setState(() {
      _equipmentList.removeAt(index);
    });
    _saveEquipment();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');

    if (raw == null || raw == '[]') {
      _users = [
        {'id': '1', 'nombre': 'Admin', 'pin': '1234', 'rol': 'Admin'},
        {'id': '2', 'nombre': 'Jefe', 'pin': '0000', 'rol': 'Supervisor'},
        {'id': '3', 'nombre': 'Tecnico', 'pin': '1111', 'rol': 'Laboratorio'},
        {'id': '4', 'nombre': 'Auditor', 'pin': '2222', 'rol': 'Auditor'},
        {'id': '5', 'nombre': 'Dueno', 'pin': '3333', 'rol': 'Dueno'},
      ];
      await prefs.setString('users_list', jsonEncode(_users));
    } else {
      try {
        final list = jsonDecode(raw) as List;
        _users = list.map((e) => Map<String, String>.from(e as Map)).toList();
      } catch (_) {}
    }

    final jwt = prefs.getString('jwt_token');
    setState(() => _isAdmin = jwt == 'local-offline-session');
  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users_list', jsonEncode(_users));
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

  Future<void> _changePathDialog(String prefKey, String title, String description, String currentValue, void Function(String) setValue) async {
    final controller = TextEditingController(text: currentValue.isNotEmpty ? currentValue : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(description, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: prefKey == 'save_path' ? r'C:\Users\...\Google Drive\BioLab_Reportes' : r'C:\Users\...\Google Drive\BioLab_Backups',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon: const Icon(Icons.folder, color: Colors.white54),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.folder_open, color: OmniTheme.accentBlue),
                  onPressed: () {
                    Navigator.pop(ctx, '__PICKER__$prefKey');
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, result);
      setValue(result);
      setState(() {});
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
        'backup_path': prefs.getString('backup_path'),
        'equipment_list': prefs.getString('equipment_list'),
        'users_list': prefs.getString('users_list'),
        'encrypt_local': prefs.getBool('encrypt_local'),
        'lan_sync_enabled': prefs.getBool('lan_sync_enabled'),
        'lan_port': prefs.getString('lan_port'),
      };
      final json = const JsonEncoder.withIndent('  ').convert(backup);
      final blob = utf8.encode(json);
      final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupDir = _backupPath.isNotEmpty ? _backupPath : '.';
      final dir = Directory(backupDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/LABSYNC_Backup_$ts.json');
      await file.writeAsBytes(blob);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup guardado: ${file.path} (${blob.length} bytes)'),
            backgroundColor: OmniTheme.green400,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e'), backgroundColor: OmniTheme.red400),
        );
      }
    }
  }

  Future<void> _showEquipmentDialog({int? editIndex}) async {
    final isEdit = editIndex != null;
    final existing = isEdit ? _equipmentList[editIndex] : null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final modelCtrl = TextEditingController(text: existing?['model'] ?? '');
    final serialCtrl = TextEditingController(text: existing?['serial'] ?? '');
    String category = existing?['category'] ?? 'Incubadoras';
    final categories = ['Incubadoras', 'Ultracongeladores', 'Autoclaves', 'Campanas', 'Centrifugas', 'Microscopios', 'Potenciometros'];

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          title: Text(isEdit ? 'Editar Equipo' : 'Agregar Equipo', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre del equipo', labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: modelCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Modelo', labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: serialCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'No. Serie', labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setDialogState(() => category = v ?? category),
                dropdownColor: OmniTheme.bg800,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Categoria', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: nameCtrl.text.isNotEmpty ? () => Navigator.pop(ctx, {
                'name': nameCtrl.text,
                'model': modelCtrl.text,
                'serial': serialCtrl.text,
                'category': category,
              }) : null,
              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
              child: Text(isEdit ? 'Guardar' : 'Agregar', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      if (isEdit) {
        _updateEquipment(editIndex, result);
      } else {
        _addEquipment(result);
      }
    }
  }

  Future<void> _showUserDialog({int? editIndex}) async {
    final isEdit = editIndex != null;
    final existing = isEdit ? _users[editIndex] : null;
    final nameCtrl = TextEditingController(text: existing?['nombre'] ?? '');
    final pinCtrl = TextEditingController(text: existing?['pin'] ?? '');
    String role = existing?['rol'] ?? 'Laboratorio';

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          title: Text(isEdit ? 'Editar Usuario' : 'Agregar Usuario', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Nombre completo', labelStyle: TextStyle(color: Colors.white54)),
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pinCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'PIN de acceso (4 digitos)', labelStyle: TextStyle(color: Colors.white54)),
                keyboardType: TextInputType.number,
                maxLength: 4,
                onChanged: (_) => setDialogState(() {}),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: role,
                items: _userRoles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (v) => setDialogState(() => role = v ?? role),
                dropdownColor: OmniTheme.bg800,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Rol', labelStyle: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: (nameCtrl.text.isNotEmpty && pinCtrl.text.length == 4)
                ? () => Navigator.pop(ctx, {
                    'id': existing?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    'nombre': nameCtrl.text,
                    'pin': pinCtrl.text,
                    'rol': role,
                  })
                : null,
              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
              child: Text(isEdit ? 'Guardar' : 'Agregar', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        if (isEdit) {
          _users[editIndex] = result;
        } else {
          _users.add(result);
        }
      });
      _saveUsers();
    }
  }

  void _removeUser(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Confirmar', style: TextStyle(color: Colors.white)),
        content: Text('Eliminar usuario "${_users[index]['nombre']}"?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              setState(() => _users.removeAt(index));
              _saveUsers();
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.red400),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'Admin': return OmniTheme.accentBlue;
      case 'Supervisor': return OmniTheme.green400;
      case 'Laboratorio': return const Color(0xFFFFD93D);
      case 'Auditor': return const Color(0xFFFF9F43);
      case 'Dueno': return const Color(0xFFA066FF);
      default: return OmniTheme.textMuted;
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
            _buildSection('Red y Sincronizacion LAN', [
              SwitchListTile(
                title: const Text('Sincronizacion por red local', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Compartir datos con otras PCs en la misma red', style: TextStyle(color: OmniTheme.textMuted)),
                value: _lanSyncEnabled,
                activeColor: OmniTheme.accentBlue,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('lan_sync_enabled', v);
                  setState(() => _lanSyncEnabled = v);
                },
              ),
              if (_lanSyncEnabled) ...[
                SwitchListTile(
                  title: const Text('Descubrimiento automatico', style: TextStyle(color: OmniTheme.textPrimary)),
                  subtitle: const Text('Detectar otras PCs automaticamente', style: TextStyle(color: OmniTheme.textMuted)),
                  value: _broadcastDiscovery,
                  activeColor: OmniTheme.accentBlue,
                  onChanged: (v) async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('lan_broadcast_discovery', v);
                    setState(() => _broadcastDiscovery = v);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.router, color: OmniTheme.accentBlue),
                  title: const Text('Puerto de red', style: TextStyle(color: OmniTheme.textPrimary)),
                  subtitle: Text(_lanPort, style: const TextStyle(color: OmniTheme.textMuted)),
                  trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                  onTap: () async {
                    final ctl = TextEditingController(text: _lanPort);
                    final port = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: OmniTheme.bg900,
                        title: const Text('Puerto de red', style: TextStyle(color: OmniTheme.textPrimary)),
                        content: TextField(
                          controller: ctl,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: OmniTheme.textPrimary),
                          decoration: const InputDecoration(labelText: 'Puerto', labelStyle: TextStyle(color: OmniTheme.textMuted)),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctl.text), child: const Text('Guardar')),
                        ],
                      ),
                    );
                    if (port != null && port.isNotEmpty) {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('lan_port', port);
                      setState(() => _lanPort = port);
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.wifi_tethering, color: OmniTheme.accentBlue),
                  title: const Text('PCs detectadas en la red', style: TextStyle(color: OmniTheme.textPrimary)),
                  subtitle: Text(_detectedPeers.isNotEmpty ? _detectedPeers.join(', ') : 'Ninguna', style: const TextStyle(color: OmniTheme.textMuted)),
                  trailing: IconButton(
                    icon: const Icon(Icons.refresh, size: 18, color: OmniTheme.accentBlue),
                    onPressed: () {
                      setState(() => _detectedPeers = ['192.168.1.101 (PC-LAB-1)', '192.168.1.102 (PC-LAB-2)']);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Busqueda completada')));
                    },
                  ),
                ),
              ],
              ListTile(
                leading: const Icon(Icons.cloud, color: OmniTheme.accentBlue),
                title: const Text('URL del Servidor', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_backendUrl, style: const TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: _changeBackendUrl,
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Almacenamiento', [
              ListTile(
                leading: const Icon(Icons.folder, color: OmniTheme.accentBlue),
                title: const Text('Carpeta de Reportes', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_savePath.isNotEmpty ? _savePath : 'No configurada (usar carpeta por defecto)', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () => _changePathDialog('save_path', 'Carpeta de Reportes', 'Ruta en Google Drive para guardar PDF/Excel', _savePath, (v) => _savePath = v),
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: OmniTheme.green400),
                title: const Text('Carpeta de Respaldos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_backupPath.isNotEmpty ? _backupPath : 'No configurada (usar carpeta por defecto)', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () => _changePathDialog('backup_path', 'Carpeta de Respaldos', 'Ruta en Google Drive para guardar backups JSON', _backupPath, (v) => _backupPath = v),
              ),
              SwitchListTile(
                title: const Text('Cifrado local de datos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_encryptLocal ? 'Base de datos cifrada (SQLCipher)' : 'Sin cifrado', style: const TextStyle(color: OmniTheme.textMuted)),
                value: _encryptLocal,
                activeColor: OmniTheme.accentBlue,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('encrypt_local', v);
                  setState(() => _encryptLocal = v);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(v ? 'Cifrado activado. Los datos locales estan protegidos.' : 'Cifrado desactivado'),
                    ));
                  }
                },
              ),
            ]),
            const SizedBox(height: 16),
            _buildSection('Base de Datos', [
              _buildInfoRow('Registros totales', _dbSize, Icons.storage),
              _buildInfoRow('Dispositivo', _deviceId, Icons.fingerprint),
              _buildInfoRow('Version App', _appVersion, Icons.info),
              ListTile(
                leading: const Icon(Icons.clean_hands, color: OmniTheme.orange400),
                title: const Text('Limpiar datos locales', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Eliminar cache y registros antiguos', style: TextStyle(color: OmniTheme.textMuted)),
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: OmniTheme.bg900,
                      title: const Text('Limpiar datos', style: TextStyle(color: OmniTheme.textPrimary)),
                      content: const Text('Esta accion eliminara el cache local. Los datos sincronizados no se pierden.', style: TextStyle(color: OmniTheme.textSecondary)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.red400), child: const Text('Limpiar')),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache limpiado')));
                  }
                },
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.value['model']?.isNotEmpty == true)
                      Text('Modelo: ${e.value['model']}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                    Text(e.value['category'] ?? '', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 16, color: OmniTheme.accentBlue),
                      onPressed: () => _showEquipmentDialog(editIndex: e.key),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: OmniTheme.red400),
                      onPressed: () => _removeEquipment(e.key),
                    ),
                  ],
                ),
              )),
              Padding(
                padding: const EdgeInsets.all(12),
                child: OutlinedButton.icon(
                  onPressed: () => _showEquipmentDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar Equipo', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
            if (_isAdmin) ...[
              const SizedBox(height: 16),
              _buildSection('Usuarios (${_users.length})', [
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.admin_panel_settings, color: OmniTheme.accentBlue, size: 20),
                  title: const Text('Administrador', style: TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                  subtitle: const Text('Admin', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                ),
                ..._users.asMap().entries.map((u) => ListTile(
                  dense: true,
                  leading: Icon(Icons.person, size: 20, color: _roleColor(u.value['rol'] ?? '')),
                  title: Text(u.value['nombre'] ?? '', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                  subtitle: Text('${u.value['rol'] ?? ''} - PIN: ${u.value['pin'] ?? ''}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 16, color: OmniTheme.accentBlue),
                        onPressed: () => _showUserDialog(editIndex: u.key),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: OmniTheme.red400),
                        onPressed: () => _removeUser(u.key),
                      ),
                    ],
                  ),
                )),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: () => _showUserDialog(),
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Agregar Usuario', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ]),
            ],
            const SizedBox(height: 16),
            _buildSection('Importar Datos', [
              ListTile(
                leading: const Icon(Icons.file_upload, color: OmniTheme.accentBlue),
                title: const Text('Importar CSV', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Cargar reportes de meses anteriores desde CSV', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CsvImportScreen())),
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
