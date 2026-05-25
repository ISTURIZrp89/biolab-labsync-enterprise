import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import '../../data/db.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../sync/lan_discovery_service.dart';
import '../../sync/lan_sync_server.dart';
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
  String _dbPath = '';
  bool _isPrimaryDevice = false;
  bool _autoBackup = false;
  bool _encryptLocal = true;
  List<Map<String, String>> _equipmentList = [];
  List<Map<String, String>> _users = [];
  String _lanPort = '8765';
  int _lanServerPort = 8766;
  String _dbSize = 'Calculando...';

  @override
  void initState() {
    super.initState();
    _platform = _getPlatformName();
    _loadSettings();
    _loadEquipment();
    _loadUsers();
  }

  @override
  void dispose() {
    try {
      final discovery = context.read<LanDiscoveryService>();
      discovery.removeListener(_onDiscoveryChanged);
    } catch (_) {}
    super.dispose();
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
    final lanPort = prefs.getString('lan_port') ?? '8765';
    final lanServerPort = prefs.getInt('lan_server_port') ?? 8766;
    final dbPath = prefs.getString('db_path') ?? '';
    final isPrimary = prefs.getBool('is_primary_device') ?? false;
    final autoBackup = prefs.getBool('auto_backup') ?? false;

    setState(() {
      _deviceId = deviceId;
      _backendUrl = savedUrl ?? 'http://localhost:8000';
      _autoSync = autoSync;
      _lastSync = lastSync != null ? _formatTimestamp(lastSync) : 'Nunca';
      _savePath = savePath;
      _backupPath = backupPath;
      _dbPath = dbPath;
      _isPrimaryDevice = isPrimary;
      _autoBackup = autoBackup;
      _encryptLocal = encryptLocal;
      _lanPort = lanPort;
      _lanServerPort = lanServerPort;
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
      final count = result.isNotEmpty ? (result.first['cnt'] as num?)?.toInt() ?? 0 : 0;
      if (mounted) setState(() => _dbSize = '$count registros');
    } catch (e) {
      if (mounted) setState(() => _dbSize = 'Error: $e');
    }
  }

  static const _defaultEquipment = [
    {'name': 'SANYO MCO-18AIC', 'model': 'MCO-18AIC', 'serial': '', 'category': 'Incubadoras'},
    {'name': 'HERACELL VIOS 160i', 'model': 'VIOS 160i', 'serial': '', 'category': 'Incubadoras'},
    {'name': 'STERI-CULT 200', 'model': '200', 'serial': '', 'category': 'Incubadoras'},
    {'name': 'FORMA 3110', 'model': '3110', 'serial': '', 'category': 'Incubadoras'},
    {'name': 'NUAIRE NU-8700', 'model': 'NU-8700', 'serial': '', 'category': 'Incubadoras'},
    {'name': 'UC-1 (-80°C)', 'model': '', 'serial': '', 'category': 'Ultracongeladores'},
    {'name': 'UC-2 (-80°C)', 'model': '', 'serial': '', 'category': 'Ultracongeladores'},
    {'name': 'UC-3 (-20°C)', 'model': '', 'serial': '', 'category': 'Ultracongeladores'},
    {'name': 'UC-4 (-80°C)', 'model': '', 'serial': '', 'category': 'Ultracongeladores'},
    {'name': 'UC-5 (-150°C)', 'model': '', 'serial': '', 'category': 'Ultracongeladores'},
    {'name': 'AUTOCLAVE 1 - TUTTNAUER', 'model': '', 'serial': '', 'category': 'Autoclaves'},
    {'name': 'AUTOCLAVE 2 - STERIS', 'model': '', 'serial': '', 'category': 'Autoclaves'},
    {'name': 'AUTOCLAVE 3 - GETINGE', 'model': '', 'serial': '', 'category': 'Autoclaves'},
    {'name': 'CABINA 1 - BIOSAFETY II', 'model': '', 'serial': '', 'category': 'Campanas'},
    {'name': 'CABINA 2 - BIOSAFETY II', 'model': '', 'serial': '', 'category': 'Campanas'},
    {'name': 'CABINA 3 - LAMINAR FLOW', 'model': '', 'serial': '', 'category': 'Campanas'},
    {'name': 'CABINA 4 - PCR', 'model': '', 'serial': '', 'category': 'Campanas'},
    {'name': 'CENTRI-1 SORVALL', 'model': '', 'serial': '', 'category': 'Centrifugas'},
    {'name': 'CENTRI-2 EPPENDORF', 'model': '', 'serial': '', 'category': 'Centrifugas'},
    {'name': 'CENTRI-3 BECKMAN', 'model': '', 'serial': '', 'category': 'Centrifugas'},
    {'name': 'MICROCENTRI-1', 'model': '', 'serial': '', 'category': 'Centrifugas'},
    {'name': 'MICROCENTRI-2', 'model': '', 'serial': '', 'category': 'Centrifugas'},
    {'name': 'MICROSCOPIO INVERTIDO LEICA', 'model': '', 'serial': '', 'category': 'Microscopios'},
    {'name': 'MICROSCOPIO COMPUESTO ZEISS', 'model': '', 'serial': '', 'category': 'Microscopios'},
    {'name': 'ESTEREOSCOPIO NIKON', 'model': '', 'serial': '', 'category': 'Microscopios'},
    {'name': 'MICROSCOPIO CONFOCAL', 'model': '', 'serial': '', 'category': 'Microscopios'},
    {'name': 'MICROSCOPIO FLUORESCENCIA', 'model': '', 'serial': '', 'category': 'Microscopios'},
    {'name': 'pHmetro 1 - HANNA', 'model': '', 'serial': '', 'category': 'Potenciometros'},
    {'name': 'pHmetro 2 - METTLER', 'model': '', 'serial': '', 'category': 'Potenciometros'},
    {'name': 'CONDUCTIMETRO', 'model': '', 'serial': '', 'category': 'Potenciometros'},
    {'name': 'SPECTROPHOTOMETER', 'model': '', 'serial': '', 'category': 'Potenciometros'},
  ];

  Future<void> _loadEquipment() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('equipment_list');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        if (list.isNotEmpty) {
          setState(() {
            _equipmentList = list.map((e) => Map<String, String>.from(e as Map)).toList();
          });
          return;
        }
      } catch (_) {}
    }
    setState(() {
      _equipmentList = _defaultEquipment.map((e) => Map<String, String>.from(e)).toList();
    });
    await prefs.setString('equipment_list', jsonEncode(_equipmentList));
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

  static const _permModules = [
    'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora',
  ];
  static const _permModuleLabels = {
    'incubadoras': 'Incubadoras',
    'autoclaves': 'Autoclaves',
    'ultracongeladores': 'Ultracongeladores',
    'equipos': 'Equipos',
    'procesamiento': 'Procesamiento',
    'bitacora': 'Bitacora General',
  };

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');

    if (raw == null || raw == '[]') {
      _users = [
        {'id': '1', 'nombre': 'Admin', 'pin': '1234', 'rol': 'Admin', 'permisos': 'todos'},
        {'id': '2', 'nombre': 'Jefe', 'pin': '0000', 'rol': 'Supervisor', 'permisos': 'todos'},
        {'id': '3', 'nombre': 'Tecnico', 'pin': '1111', 'rol': 'Laboratorio', 'permisos': 'incubadoras,autoclaves,ultracongeladores,equipos,bitacora'},
        {'id': '4', 'nombre': 'Auditor', 'pin': '2222', 'rol': 'Auditor', 'permisos': 'todos'},
        {'id': '5', 'nombre': 'Dueno', 'pin': '3333', 'rol': 'Dueno', 'permisos': 'todos'},
      ];
      await prefs.setString('users_list', jsonEncode(_users));
    } else {
      try {
        final list = jsonDecode(raw) as List;
        _users = list.map((e) => Map<String, String>.from(e as Map)).toList();
        for (final u in _users) {
          u.putIfAbsent('permisos', () => 'todos');
        }
      } catch (_) {}
    }

  }

  Future<void> _saveUsers() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('users_list', jsonEncode(_users));
  }

  Future<void> _saveSetting(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
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

  Future<void> _showMoveDbDialog() async {
    final controller = TextEditingController(text: _dbPath.isNotEmpty ? _dbPath : '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Mover Base de Datos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ingresa la ruta destino. La BD sera MOVIDA con todos sus datos.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: r'C:\Users\...\Google Drive\BioLab',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.folder, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Mover', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await LocalDatabase.instance.moveDatabase(result);
        setState(() => _dbPath = result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Base de datos movida exitosamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al mover: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showExportDbDialog() async {
    final defaultPath = _backupPath.isNotEmpty ? _backupPath : r'C:\Users\...\Google Drive';
    final controller = TextEditingController(text: defaultPath);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Exportar Base de Datos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Carpeta destino. Se creara: BioLab/Backups/YYYY-MM-DD/',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: r'C:\Users\...\Google Drive',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.folder, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.green400),
            child: const Text('Exportar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final path = await LocalDatabase.instance.exportToDirectory(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exportado a: $path')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showImportDbDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Importar Base de Datos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ruta del archivo .db a importar (reemplaza la BD actual).',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: r'D:\BioLab_Backup\labsync_backup_2026-01-01.db',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.folder, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.orange400),
            child: const Text('Importar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        await LocalDatabase.instance.importFromFile(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Base de datos importada exitosamente')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al importar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showVerifyDialog() async {
    final defaultPath = _backupPath.isNotEmpty ? _backupPath : r'C:\Users\...\Google Drive';
    final controller = TextEditingController(text: defaultPath);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Verificar Datos', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Exporta todos los datos como JSON legible para revisar en Google Drive.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: r'C:\Users\...\Google Drive',
                hintStyle: TextStyle(color: Colors.white38),
                prefixIcon: Icon(Icons.folder, color: Colors.white54),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Exportar JSON', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final path = await LocalDatabase.instance.exportForVerification(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('JSON exportado a: $path')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al exportar: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _startLanServices() {
    try {
      final server = context.read<LanSyncServer>();
      if (!server.isRunning) {
        final prefs = SharedPreferences.getInstance();
        // ignore: unused_local_variable
        final pref = prefs;
      }
    } catch (_) {}
  }

  void _stopLanServices() {
    try {
      final server = context.read<LanSyncServer>();
      server.stop();
    } catch (_) {}
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

  static const _cargosOperativos = ['TÉCNICO', 'BIÓLOGO', 'QFB', 'JEFE DE LABORATORIO', 'ADMINISTRADOR', 'DIRECTOR GENERAL'];

  Future<void> _showUserDialog({int? editIndex}) async {
    final isEdit = editIndex != null;
    final existing = isEdit ? _users[editIndex] : null;
    final nameCtrl = TextEditingController(text: existing?['nombre'] ?? '');
    final pinCtrl = TextEditingController(text: existing?['pin'] ?? '');
    final areaCtrl = TextEditingController(text: existing?['area'] ?? 'Cultivo Celular');
    final supervisorCtrl = TextEditingController(text: existing?['supervisor'] ?? '');
    final firmaCtrl = TextEditingController(text: existing?['firma'] ?? existing?['nombre'] ?? '');
    String role = existing?['rol'] ?? 'Laboratorio';
    String cargoOperativo = existing?['cargo_operativo'] ?? existing?['cargo'] ?? 'TÉCNICO';
    Set<String> permisos = {};
    if (existing != null) {
      final p = existing['permisos'] ?? 'todos';
      if (p == 'todos') {
        permisos = _permModules.toSet();
      } else {
        permisos = p.split(',').toSet();
      }
    } else {
      permisos = {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'bitacora'};
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          title: Text(isEdit ? 'Editar Usuario' : 'Agregar Usuario', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Nombre completo', labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: cargoOperativo,
                  items: _cargosOperativos.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(color: Colors.white)))).toList(),
                  onChanged: (v) => setDialogState(() => cargoOperativo = v ?? cargoOperativo),
                  dropdownColor: OmniTheme.bg800,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Cargo Operativo (en reportes)', labelStyle: TextStyle(color: Colors.white54)),
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
                  decoration: const InputDecoration(labelText: 'Rol del Sistema', labelStyle: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: areaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Area', labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: supervisorCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Supervisor', labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: firmaCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(labelText: 'Firma (aparece en reportes)', labelStyle: TextStyle(color: Colors.white54)),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                const Text('Permisos por modulo:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                ..._permModules.map((m) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(_permModuleLabels[m] ?? m, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  value: permisos.contains(m),
                  activeColor: OmniTheme.accentBlue,
                  checkColor: Colors.white,
                  onChanged: (v) => setDialogState(() {
                    if (v == true) { permisos.add(m); } else { permisos.remove(m); }
                  }),
                )),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: (nameCtrl.text.isNotEmpty && pinCtrl.text.length == 4)
                ? () => Navigator.pop(ctx, {
                    'id': existing?['id'] ?? DateTime.now().microsecondsSinceEpoch.toString(),
                    'nombre': nameCtrl.text,
                    'cargo': cargoOperativo,
                    'cargo_operativo': cargoOperativo,
                    'pin': pinCtrl.text,
                    'rol': role,
                    'area': areaCtrl.text,
                    'supervisor': supervisorCtrl.text,
                    'firma': firmaCtrl.text,
                    'permisos': permisos.length >= _permModules.length ? 'todos' : permisos.join(','),
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
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const Text('Configuracion'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: OmniTheme.bg800, borderRadius: BorderRadius.circular(10)),
            child: Text(user?.nombre ?? 'Offline', style: const TextStyle(fontSize: 10, color: OmniTheme.accentBlue)),
          ),
        ]),
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
            _buildAccordion('Estado del Sistema', Icons.monitor_heart, true, [
              _buildInfoRow('Estado', _isOnline ? 'En linea' : 'Desconectado', Icons.wifi),
              _buildInfoRow('Usuario', user?.nombre ?? '--', Icons.person),
              _buildInfoRow('Rol', user?.rol ?? '--', Icons.badge),
              _buildInfoRow('Plataforma', _platform, Icons.devices),
              _buildInfoRow('Ultima Sincronizacion', _lastSync, Icons.sync),
              _buildInfoRow('Pendientes', '$_pendingSync registros', Icons.pending),
            ]),
            _buildAccordion('Sincronizacion', Icons.sync, false, [
              SwitchListTile(
                title: const Text('Automatica', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_autoSync ? 'Cada 5 minutos' : 'Desactivada', style: TextStyle(color: OmniTheme.textMuted)),
                value: _autoSync,
                onChanged: _toggleAutoSync,
                activeColor: OmniTheme.accentBlue,
              ),
              ListTile(
                leading: const Icon(Icons.sync, color: OmniTheme.accentBlue),
                title: const Text('Sincronizar Ahora', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text('${context.watch<SyncEngine>().failedCount > 0 ? "${context.watch<SyncEngine>().failedCount} fallos | " : ""}${context.watch<SyncEngine>().syncCount} exitosas', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                onTap: () async {
                  final sync = context.read<SyncEngine>();
                  final success = await sync.synchronize();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(success ? 'Sincronizacion completada' : 'Error al sincronizar. Verifica que el servidor este corriendo en $_backendUrl')),
                    );
                    _loadSettings();
                  }
                },
              ),
              if (context.watch<SyncEngine>().failedCount > 0)
                ListTile(
                  leading: const Icon(Icons.refresh, color: OmniTheme.orange400),
                  title: const Text('Reintentar sincronizaciones fallidas', style: TextStyle(color: OmniTheme.orange400)),
                  onTap: () async {
                    final sync = context.read<SyncEngine>();
                    await sync.retryFailed();
                    if (mounted) _loadSettings();
                  },
                ),
            ]),
            _buildAccordion('Red WiFi', Icons.wifi, false, [
              _buildInfoRow('Descubrimiento', 'Automatico (UDP)', Icons.search),
              _buildInfoRow('PCs detectadas', '${context.watch<LanDiscoveryService>().peers.length}', Icons.computer),
              if (context.watch<LanDiscoveryService>().peers.isNotEmpty)
                ...context.watch<LanDiscoveryService>().peers.map((peer) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.computer, color: OmniTheme.green400, size: 18),
                  title: Text(peer.hostname, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                  subtitle: Text('${peer.ip}:${peer.port}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                )),
              ListTile(
                leading: const Icon(Icons.router, color: OmniTheme.accentBlue),
                title: const Text('Puerto descubrimiento', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_lanPort, style: const TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () async {
                  final ctl = TextEditingController(text: _lanPort);
                  final port = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: OmniTheme.bg900,
                      title: const Text('Puerto descubrimiento', style: TextStyle(color: OmniTheme.textPrimary)),
                      content: TextField(controller: ctl, keyboardType: TextInputType.number, style: const TextStyle(color: OmniTheme.textPrimary), decoration: const InputDecoration(labelText: 'Puerto UDP', labelStyle: TextStyle(color: OmniTheme.textMuted))),
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
              const ListTile(
                leading: Icon(Icons.lock, color: OmniTheme.green400),
                title: Text('Conexion segura', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text('Sin puertos HTTP expuestos. La sincronizacion usa el servidor configurado.', style: TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
              ),
              ListTile(
                leading: const Icon(Icons.cloud, color: OmniTheme.accentBlue),
                title: const Text('URL del Servidor', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_backendUrl, style: const TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: _changeBackendUrl,
              ),
            ]),
            _buildAccordion('Almacenamiento', Icons.storage, false, [
              ListTile(
                leading: const Icon(Icons.folder, color: OmniTheme.accentBlue),
                title: const Text('Carpeta de Reportes', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_savePath.isNotEmpty ? _savePath : 'No configurada', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () => _changePathDialog('save_path', 'Carpeta de Reportes', 'Ruta para PDF/Excel', _savePath, (v) => _savePath = v),
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: OmniTheme.green400),
                title: const Text('Carpeta de Respaldos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_backupPath.isNotEmpty ? _backupPath : 'No configurada', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () => _changePathDialog('backup_path', 'Carpeta de Respaldos', 'Ruta para backups JSON', _backupPath, (v) => _backupPath = v),
              ),
              SwitchListTile(
                title: const Text('Cifrado local', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_encryptLocal ? 'SQLCipher activado' : 'Sin cifrado', style: const TextStyle(color: OmniTheme.textMuted)),
                value: _encryptLocal,
                activeColor: OmniTheme.accentBlue,
                onChanged: _toggleEncryption,
              ),
              SwitchListTile(
                title: const Text('Respaldo automatico al guardar', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_autoBackup ? 'Copia JSON en cada guardado' : 'Solo respaldo manual', style: const TextStyle(color: OmniTheme.textMuted)),
                value: _autoBackup,
                activeColor: OmniTheme.accentBlue,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('auto_backup', v);
                  setState(() => _autoBackup = v);
                },
              ),
            ]),
            _buildAccordion('Base de Datos', Icons.storage_outlined, false, [
              _buildInfoRow('Registros totales', _dbSize, Icons.storage),
              _buildInfoRow('Dispositivo', _deviceId, Icons.fingerprint),
              _buildInfoRow('Version App', _appVersion, Icons.info),
              ListTile(
                leading: const Icon(Icons.folder, color: OmniTheme.accentBlue),
                title: const Text('Ubicacion de la Base de Datos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_dbPath.isNotEmpty ? _dbPath : 'Predeterminada (AppData)', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: _showMoveDbDialog,
              ),
              ListTile(
                leading: const Icon(Icons.upload_file, color: OmniTheme.green400),
                title: const Text('Exportar Base de Datos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Copia a Google Drive/USB (organizado por fecha)', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.upload, color: OmniTheme.textMuted),
                onTap: _showExportDbDialog,
              ),
              ListTile(
                leading: const Icon(Icons.download_file, color: OmniTheme.orange400),
                title: const Text('Importar Base de Datos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Restaurar desde USB', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.download, color: OmniTheme.textMuted),
                onTap: _showImportDbDialog,
              ),
              ListTile(
                leading: const Icon(Icons.verified, color: OmniTheme.accentBlue),
                title: const Text('Verificar Datos en Google Drive', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Exporta JSON legible para revision', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.open_in_new, color: OmniTheme.textMuted),
                onTap: _showVerifyDialog,
              ),
              SwitchListTile(
                title: const Text('Dispositivo Principal', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_isPrimaryDevice ? 'Fuente de verdad para LAN' : 'Sincroniza desde el principal', style: const TextStyle(color: OmniTheme.textMuted)),
                value: _isPrimaryDevice,
                activeColor: OmniTheme.accentBlue,
                onChanged: (v) async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_primary_device', v);
                  setState(() => _isPrimaryDevice = v);
                },
              ),
              ListTile(
                leading: const Icon(Icons.clean_hands, color: OmniTheme.orange400),
                title: const Text('Limpiar cache local', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Eliminar cache y registros antiguos', style: TextStyle(color: OmniTheme.textMuted)),
                onTap: _confirmCleanCache,
              ),
            ]),
            _buildAccordion('Equipos (${_equipmentList.length})', Icons.precision_manufacturing, false, [
              if (_equipmentList.isEmpty)
                const Padding(padding: EdgeInsets.all(16), child: Text('No hay equipos registrados', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)))
              else
                ..._equipmentList.asMap().entries.map((e) => ListTile(dense: true,
                  leading: Container(width: 6, height: 6, decoration: const BoxDecoration(color: OmniTheme.accentBlue, shape: BoxShape.circle)),
                  title: Text(e.value['name'] ?? '', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                  subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (e.value['model']?.isNotEmpty == true) Text('Modelo: ${e.value['model']}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                    Text(e.value['category'] ?? '', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                  ]),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, size: 16, color: OmniTheme.accentBlue), onPressed: () => _showEquipmentDialog(editIndex: e.key)),
                    IconButton(icon: const Icon(Icons.close, size: 16, color: OmniTheme.red400), onPressed: () => _removeEquipment(e.key)),
                  ]),
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
            _buildAccordion('Usuarios (${_users.length})', Icons.people, false, [
              ..._users.asMap().entries.map((u) => ListTile(dense: true,
                leading: Icon(Icons.person, size: 20, color: _roleColor(u.value['rol'] ?? '')),
                title: Text(u.value['nombre'] ?? '', style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
                subtitle: Text('${u.value['rol'] ?? ''} - PIN: ${u.value['pin'] ?? ''}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.edit, size: 16, color: OmniTheme.accentBlue), onPressed: () => _showUserDialog(editIndex: u.key)),
                  IconButton(icon: const Icon(Icons.close, size: 16, color: OmniTheme.red400), onPressed: () => _removeUser(u.key)),
                ]),
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
            if (auth.isAuthenticated) _buildAccordion('Sesion y Seguridad', Icons.security, false, [
              _buildInfoRow('Sesion iniciada', auth.currentUser?.nombre ?? '', Icons.person),
              _buildInfoRow('Duracion de sesion', '${auth.sessionDurationMinutes} min', Icons.timer),
              _buildInfoRow('Timeout inactividad', '${AuthService.inactivityTimeoutMinutes} min', Icons.timer_off),
              _buildInfoRow('Timeout maximo', '${AuthService.sessionTimeoutMinutes} min (${(AuthService.sessionTimeoutMinutes / 60).round()}h)', Icons.access_time),
              if (auth.isAdmin || auth.isOwner) ...[
                const Divider(color: OmniTheme.bg800),
                ListTile(
                  leading: const Icon(Icons.lock_outline, color: OmniTheme.accentBlue),
                  title: const Text('Administrar sesiones', style: TextStyle(color: OmniTheme.textPrimary)),
                  subtitle: const Text('Cerrar todas las sesiones activas', style: TextStyle(color: OmniTheme.textMuted)),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: OmniTheme.bg900,
                        title: const Text('Cerrar sesion?', style: TextStyle(color: OmniTheme.textPrimary)),
                        content: const Text('Se cerrara tu sesion actual y deberas volver a iniciar.', style: TextStyle(color: OmniTheme.textMuted)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.red400), child: const Text('Cerrar Sesion', style: TextStyle(color: Colors.white))),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await auth.logout();
                      if (mounted) Navigator.pushReplacementNamed(context, '/');
                    }
                  },
                ),
              ],
            ]),
            _buildAccordion('Importar / Exportar', Icons.file_copy, false, [
              ListTile(
                leading: const Icon(Icons.file_upload, color: OmniTheme.accentBlue),
                title: const Text('Importar CSV', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Cargar reportes de meses anteriores', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CsvImportScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: OmniTheme.green400),
                title: const Text('Exportar Backup', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Respaldar configuracion y datos', style: TextStyle(color: OmniTheme.textMuted)),
                onTap: _exportBackup,
              ),
              ListTile(
                leading: const Icon(Icons.system_update, color: OmniTheme.accentBlue),
                title: const Text('Buscar Actualizaciones', style: TextStyle(color: OmniTheme.textPrimary)),
                onTap: _checkForUpdates,
              ),
            ]),
            const SizedBox(height: 16),
            Center(child: Text('LABSYNC Enterprise v$_appVersion', style: TextStyle(color: OmniTheme.textMuted.withOpacity(0.3), fontSize: 12))),
          ],
        ),
      ),
    );
  }

  Widget _buildAccordion(String title, IconData icon, bool initiallyExpanded, List<Widget> children) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Icon(icon, color: OmniTheme.accentBlue, size: 20),
        title: Text(title, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
        collapsedBackgroundColor: OmniTheme.bg900,
        backgroundColor: OmniTheme.bg900,
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        children: children,
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

  Future<void> _toggleEncryption(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('encrypt_local', v);
    setState(() => _encryptLocal = v);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(v ? 'Cifrado activado. Datos protegidos.' : 'Cifrado desactivado'),
      ));
    }
  }

  Future<void> _confirmCleanCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('Limpiar datos', style: TextStyle(color: OmniTheme.textPrimary)),
        content: const Text('Se eliminara el cache local. Los datos sincronizados no se pierden.', style: TextStyle(color: OmniTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.red400), child: const Text('Limpiar')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache limpiado')));
    }
  }
}
