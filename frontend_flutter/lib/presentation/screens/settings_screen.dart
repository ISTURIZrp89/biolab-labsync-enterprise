import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/db.dart';
import '../../data/csv_mappings.dart';
import '../../security/auth_service.dart';
import '../../sync/sync_engine.dart';
import '../../ai/ai_service.dart';
import '../../sync/lan_discovery_service.dart';
import '../../sync/lan_sync_server.dart';
import '../../services/update_service.dart';
import '../../services/license_service.dart';
import 'backup_screen.dart';
import '../../theme/omni_theme.dart';
import '../screens/csv_import_screen.dart';
import 'ai/ai_dashboard_screen.dart';
import 'ai/ai_supervisor_screen.dart';
import 'ai/model_manager_screen.dart';
import 'ai/node_network_screen.dart';
import 'ai/shared_memory_screen.dart';
import 'bitacora_bulk_import_screen.dart';
import 'pending_import_approval_screen.dart';
import 'remote_access_screen.dart';

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
  String _driveBackupPath = '';
  String _systemPrompt = '';
  String _companyName = '';
  String _logoBase64 = '';
  List<String> _personnel = [];

  @override
  void initState() {
    super.initState();
    _platform = _getPlatformName();
    _loadSettings();
    _loadCompanyInfo();
    _loadEquipment();
    _loadUsers();
    _loadDriveBackupPath();
    _loadSystemPrompt();
  }

  @override
  void dispose() {
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

  Future<void> _loadCompanyInfo() async {
    try {
      final db = await LocalDatabase.instance.database;
      final rows = await db.query('company_info', where: 'id = ?', whereArgs: ['default']);
      if (rows.isNotEmpty) {
        final row = rows.first;
        setState(() {
          _companyName = row['company_name'] as String? ?? '';
          _logoBase64 = row['logo_base64'] as String? ?? '';
          final personnelRaw = row['personnel_json'] as String? ?? '[]';
          _personnel = (jsonDecode(personnelRaw) as List).cast<String>();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveCompanyInfo() async {
    try {
      final db = await LocalDatabase.instance.database;
      await db.insert('company_info', {
        'id': 'default',
        'company_name': _companyName,
        'logo_base64': _logoBase64,
        'personnel_json': jsonEncode(_personnel),
        'report_output_path': _savePath,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (_) {}
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
    'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'solucion_cobre',
  ];
  static const _permModuleLabels = {
    'incubadoras': 'Incubadoras',
    'autoclaves': 'Autoclaves',
    'ultracongeladores': 'Ultracongeladores',
    'equipos': 'Equipos',
    'procesamiento': 'Procesamiento',
    'bitacora': 'Bitacora General',
    'solucion_cobre': 'Solucion de Cobre',
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
      permisos = {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'solucion_cobre'};
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
        backgroundColor: OmniTheme.primary,
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
                leading: const Icon(Icons.file_download, color: OmniTheme.orange400),
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
            _buildAccordion('Empresa (Reportes)', Icons.business, false, [
              ListTile(
                leading: const Icon(Icons.edit, color: OmniTheme.accentBlue),
                title: const Text('Nombre de la empresa', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_companyName.isNotEmpty ? _companyName : 'No configurado', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () async {
                  final ctrl = TextEditingController(text: _companyName);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: OmniTheme.bg900,
                      title: const Text('Nombre de la empresa', style: TextStyle(color: Colors.white)),
                      content: TextField(controller: ctrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'BioLab S.A. de C.V.', hintStyle: TextStyle(color: Colors.white38))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                        ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue), child: const Text('Guardar', style: TextStyle(color: Colors.white))),
                      ],
                    ),
                  );
                  if (result != null) {
                    setState(() => _companyName = result);
                    _saveCompanyInfo();
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: OmniTheme.green400),
                title: const Text('Logo de la empresa', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_logoBase64.isNotEmpty ? 'Logo cargado' : 'No configurado', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () async {
                  final result = await FilePicker.platform.pickFiles(type: FileType.image);
                  if (result != null && result.files.isNotEmpty) {
                    final bytes = await File(result.files.single.path!).readAsBytes();
                    setState(() => _logoBase64 = base64Encode(bytes));
                    _saveCompanyInfo();
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logo cargado'), backgroundColor: OmniTheme.green400));
                  }
                },
              ),
              if (_logoBase64.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: OmniTheme.red400),
                  title: const Text('Eliminar logo', style: TextStyle(color: OmniTheme.red400)),
                  onTap: () {
                    setState(() => _logoBase64 = '');
                    _saveCompanyInfo();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.people, color: OmniTheme.accentBlue),
                title: const Text('Personal / Responsables', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text('${_personnel.length} persona(s)', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                onTap: () => _showPersonnelDialog(),
              ),
              ListTile(
                leading: const Icon(Icons.folder, color: OmniTheme.accentBlue),
                title: const Text('Carpeta de Reportes', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_savePath.isNotEmpty ? _savePath : 'No configurada', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, color: OmniTheme.textMuted),
                onTap: () => _changePathDialog('save_path', 'Carpeta de Reportes', 'Ruta donde se guardaran los reportes mensuales', _savePath, (v) => _savePath = v),
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
            _buildAccordion('Productos Registrados', Icons.inventory_2, false, [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Importar productos desde CSV', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: OmniTheme.accentBlue),
                  onPressed: () => _importProductsCsv(),
                ),
              ),
              _buildProductCategory('Presentaciones', 'presentacion', ['100M', '50M', '30M', 'EXOSOMAS', '100M+EXO']),
              _buildProductCategory('Volumenes', 'volumen', ['5CC', '3CC', '2CC', '1CC', '10CC']),
              _buildProductCategory('Usos Terapeuticos', 'uso', ['SISTEMICO', 'ARTICULAR RODILLA', 'ARTICULAR CADERA', 'ARTICULAR TOBILLO', 'ARTICULAR LUMBAR', 'INTRAVENOSO', 'TOPICO']),
              _buildProductCategory('Tipos de Tejido', 'tejido', ['PLACENTA', 'TEJIDO ADIPOSO', 'PULPA', 'ENDOMETRIO', 'MEMBRANA', 'GW', 'AUTOLOGAS', 'ALOGENICAS', 'EXOSOMAS', 'CORDON UMBILICAL']),
              _buildProductCategory('Tipo de Envio', 'tipo_envio', ['CELULAS', 'EXOSOMAS', 'MEDIO CONDICIONADO', 'FACTORES DE CRECIMIENTO', 'NA']),
              _buildProductCategory('Enviado a', 'enviado_a', ['INMUNOTERAPIA', 'QUANTUM', 'HOSPITAL', 'CLINICA PRIVADA', 'OTRO']),
              _buildProductCategory('Solicitado por', 'pedido_por', ['DR. JAVIER ARENAS', 'DRA. MARIA RIVERA', 'DR. CARLOS MENDOZA', 'ERICK', 'OTRO']),
            ]),
            _buildAccordion('Supervisor AI', Icons.psychology, false, [
              FutureBuilder<SharedPreferences>(
                future: SharedPreferences.getInstance(),
                builder: (ctx, snap) {
                  final prefs = snap.data;
                  final aiEnabled = prefs?.getBool('ai_enabled') ?? true;
                  return Column(children: [
                    SwitchListTile(
                      value: aiEnabled,
                      onChanged: (v) async {
                        final p = await SharedPreferences.getInstance();
                        await p.setBool('ai_enabled', v);
                        try { context.read<AiService>().enabled = v; } catch (_) {}
                        setState(() {});
                      },
                      title: const Text('Texto Predictivo', style: TextStyle(color: OmniTheme.textPrimary)),
                      subtitle: const Text('Sugerencias inteligentes al llenar formularios', style: TextStyle(color: OmniTheme.textMuted)),
                      activeColor: OmniTheme.accentBlue,
                    ),
                    const Divider(color: OmniTheme.bg800),
                    _buildSyncStatRow('Sincronizaciones', context.watch<SyncEngine>().syncCount),
                    _buildSyncStatRow('Fallos detectados', context.watch<SyncEngine>().failedCount),
                    if (context.watch<SyncEngine>().failedCount > 0) ...[
                      const Divider(color: OmniTheme.bg800),
                      ListTile(
                        leading: const Icon(Icons.refresh, color: OmniTheme.orange400),
                        title: const Text('Reintentar sincronizaciones fallidas', style: TextStyle(color: OmniTheme.textPrimary)),
                        onTap: () async {
                          try { await context.read<SyncEngine>().retryFailed(); } catch (_) {}
                        },
                      ),
                    ],
                    const Divider(color: OmniTheme.bg800),
                    ListTile(
                      leading: const Icon(Icons.auto_fix_high, color: OmniTheme.green400),
                      title: const Text('Dedup de opciones personalizadas', style: TextStyle(color: OmniTheme.textPrimary)),
                      subtitle: const Text('La IA revisa y elimina opciones duplicadas automaticamente', style: TextStyle(color: OmniTheme.textMuted)),
                    ),
                  ]);
                },
              ),
            ]),
            if (auth.isAdmin || auth.isOwner) ...[
            _buildAccordion('Administracion de IA', Icons.admin_panel_settings, false, [
              ListTile(
                leading: const Icon(Icons.dashboard, color: OmniTheme.accentBlue),
                title: const Text('Dashboard IA', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Hardware, rendimiento y estado', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiDashboardScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: OmniTheme.accentBlue),
                title: const Text('Supervisor AI Chat', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Asistente con IA local para supervision y diagnostico', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AiSupervisorScreen(userRole: auth.currentUser?.rol ?? 'AUDITOR'))),
              ),
              ListTile(
                leading: const Icon(Icons.model_training, color: Color(0xFFB197FC)),
                title: const Text('Gestor de Modelos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Descargar, instalar y activar modelos IA', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ModelManagerScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.assistant, color: const Color(0xFF00BCD4)),
                title: const Text('System Prompt del Asistente', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_systemPrompt.isEmpty ? 'Configurar prompt del asistente IA' : (_systemPrompt.length > 40 ? '${_systemPrompt.substring(0, 40)}...' : _systemPrompt), style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                trailing: const Icon(Icons.edit, size: 14, color: OmniTheme.accentBlue),
                onTap: () => _editSystemPrompt(),
              ),
              ListTile(
                leading: const Icon(Icons.hub, color: OmniTheme.green400),
                title: const Text('Red de Nodos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Gestionar red distribuida de equipos', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NodeNetworkScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.memory, color: OmniTheme.orange400),
                title: const Text('Memoria Compartida', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Entradas, embedding y sincronizacion entre nodos', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SharedMemoryScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.file_upload_outlined, color: OmniTheme.accentBlue),
                title: const Text('Importar Bitacoras Anteriores', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Cargar CSV de meses anteriores con IA', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BitacoraBulkImportScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.checklist, color: OmniTheme.green400),
                title: const Text('Aprobar Importaciones Pendientes', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Revisar y aceptar datos importados por la IA', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingImportApprovalScreen())),
              ),
              const Divider(color: OmniTheme.bg800, height: 1),
              ListTile(
                leading: const Icon(Icons.vpn_key, color: OmniTheme.orange400),
                title: const Text('Clave de Activacion', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(context.watch<LicenseService>().storedKey != null
                    ? '${context.watch<LicenseService>().storedKey!.substring(0, 4)}... (${context.watch<LicenseService>().branch ?? "activa"})'
                    : 'No configurada', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, size: 16, color: OmniTheme.textMuted),
                onTap: () async {
                  final controller = TextEditingController(text: context.read<LicenseService>().storedKey ?? '');
                  final newKey = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: OmniTheme.bg900,
                      title: const Text('Cambiar Clave de Activacion', style: TextStyle(color: Colors.white)),
                      content: TextField(
                        controller: controller,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Nueva clave',
                          labelStyle: TextStyle(color: Colors.white54),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
                          child: const Text('Cambiar y Reactivar', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (newKey != null && newKey.isNotEmpty && mounted) {
                    final license = context.read<LicenseService>();
                    final ok = await license.activate(newKey);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Clave actualizada correctamente' : 'Error: ${license.lastError}'),
                        backgroundColor: ok ? OmniTheme.green400 : OmniTheme.red400,
                      ));
                      setState(() {});
                    }
                  }
                },
              ),
              const Divider(color: OmniTheme.bg800, height: 1),
              ListTile(
                leading: const Icon(Icons.key, color: OmniTheme.accentBlue),
                title: const Text('Token de GitHub', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Necesario para verificar licencia en este equipo', style: TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                trailing: const Icon(Icons.edit, size: 16, color: OmniTheme.textMuted),
                onTap: () async {
                  final license = context.read<LicenseService>();
                  final controller = TextEditingController();
                  final newToken = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: OmniTheme.bg900,
                      title: const Text('Token de GitHub', style: TextStyle(color: Colors.white)),
                      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('Ingrese el token de acceso personal de GitHub con acceso al repositorio privado de licencias.', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: controller,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'GitHub Token',
                            labelStyle: TextStyle(color: Colors.white54),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ]),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                          style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
                          child: const Text('Guardar Token', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                  if (newToken != null && newToken.isNotEmpty && mounted) {
                    await LicenseService.setToken(newToken);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Token guardado. Intente reactivar la licencia.'),
                      backgroundColor: OmniTheme.green400,
                    ));
                  }
                },
              ),
            ],
            ),
            _buildAccordion('Red y Acceso Remoto', Icons.public, false, [
              ListTile(
                leading: const Icon(Icons.devices, color: OmniTheme.accentBlue),
                title: const Text('Dispositivos en Red', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Ver equipos conectados en la LAN', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteAccessScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.cloud_upload, color: OmniTheme.green400),
                title: const Text('Conexion VPS', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Conectar dispositivos remotos via VPS', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteAccessScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.history, color: OmniTheme.orange400),
                title: const Text('Auditoria de Actividades', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Registro de accesos, cambios y conexiones', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteAccessScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.folder_copy, color: OmniTheme.accentBlue),
                title: const Text('Carpeta de Backup en Drive', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: Text(_driveBackupPath.isEmpty ? 'Configurar ruta de respaldo' : _driveBackupPath, style: TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: _pickDriveFolder,
              ),
            ],
            ),
            ],
            _buildAccordion('Importar / Exportar', Icons.file_copy, false, [
              ListTile(
                leading: const Icon(Icons.file_upload, color: OmniTheme.accentBlue),
                title: const Text('Importar CSV (Equipos)', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Cargar reportes de equipos', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CsvImportScreen())),
              ),
              ListTile(
                leading: const Icon(Icons.backup, color: OmniTheme.green400),
                title: const Text('Respaldos', style: TextStyle(color: OmniTheme.textPrimary)),
                subtitle: const Text('Ver, restaurar y crear backups', style: TextStyle(color: OmniTheme.textMuted)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: OmniTheme.textMuted),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BackupScreen())),
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
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shadowColor: OmniTheme.accentBlue.withOpacity(0.1),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.only(bottom: 8),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: OmniTheme.accentBlue.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: OmniTheme.accentBlue, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        collapsedBackgroundColor: OmniTheme.bg900,
        backgroundColor: OmniTheme.bg800.withOpacity(0.5),
        collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: children.map((child) {
          if (child is ListTile) {
            return ListTile(
              key: child.key,
              leading: child.leading,
              title: child.title,
              subtitle: child.subtitle,
              trailing: child.trailing,
              onTap: child.onTap,
              dense: child.dense,
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              hoverColor: OmniTheme.accentBlue.withOpacity(0.08),
              splashColor: OmniTheme.accentBlue.withOpacity(0.15),
              enabled: child.onTap != null,
              style: ListTileStyle.list,
              visualDensity: VisualDensity.standard,
            );
          }
          return child;
        }).toList(),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: OmniTheme.accentBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: OmniTheme.accentBlue, size: 20),
      ),
      title: Text(label, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w500)),
      subtitle: Text(value, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
      dense: false,
    );
  }

  Widget _buildSyncStatRow(String label, int count) {
    return ListTile(
      leading: Icon(count > 0 ? Icons.warning_amber_rounded : Icons.check_circle, color: count > 0 ? OmniTheme.orange400 : OmniTheme.green400, size: 20),
      title: Text(label, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14)),
      trailing: Text('$count', style: TextStyle(color: count > 0 ? OmniTheme.orange400 : OmniTheme.textMuted, fontWeight: FontWeight.bold)),
      dense: true,
    );
  }

  Widget _buildProductCategory(String label, String key, List<String> defaults) {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (ctx, snap) {
        final custom = snap.data?.getStringList('custom_opts_$key') ?? [];
        final all = {...defaults, ...custom}.toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 8, bottom: 4),
              child: Text(label.toUpperCase(), style: const TextStyle(color: OmniTheme.accentBlue, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            ...all.map((opt) => ListTile(
              dense: true,
              title: Text(opt, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
              trailing: custom.contains(opt)
                  ? IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: OmniTheme.red400),
                      onPressed: () async {
                        final p = await SharedPreferences.getInstance();
                        final updated = (p.getStringList('custom_opts_$key') ?? [])..remove(opt);
                        await p.setStringList('custom_opts_$key', updated);
                        setState(() {});
                      },
                    )
                  : null,
            )),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Agregar', style: TextStyle(fontSize: 12)),
                onPressed: () => _showAddOptionDialog(key, label),
              ),
            ),
            const Divider(height: 4, color: OmniTheme.bg800),
          ],
        );
      },
    );
  }

  Future<void> _showAddOptionDialog(String key, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: Text('Agregar $label', style: const TextStyle(color: Colors.white, fontSize: 15)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Nueva opcion...',
            hintStyle: const TextStyle(color: OmniTheme.textMuted),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: OmniTheme.accentBlue)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: OmniTheme.textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      final p = await SharedPreferences.getInstance();
      final existing = p.getStringList('custom_opts_$key') ?? [];
      if (!existing.contains(result) && !['100M', '50M', '30M', 'EXOSOMAS', '100M+EXO', '5CC', '3CC', '2CC', '1CC', '10CC', 'SISTEMICO', 'ARTICULAR RODILLA', 'ARTICULAR CADERA', 'ARTICULAR TOBILLO', 'ARTICULAR LUMBAR', 'INTRAVENOSO', 'TOPICO', 'PLACENTA', 'TEJIDO ADIPOSO', 'PULPA', 'ENDOMETRIO', 'MEMBRANA', 'GW', 'AUTOLOGAS', 'ALOGENICAS', 'EXOSOMAS', 'CORDON UMBILICAL', 'CELULAS', 'MEDIO CONDICIONADO', 'FACTORES DE CRECIMIENTO', 'NA', 'INMUNOTERAPIA', 'QUANTUM', 'HOSPITAL', 'CLINICA PRIVADA', 'OTRO', 'DR. JAVIER ARENAS', 'DRA. MARIA RIVERA', 'DR. CARLOS MENDOZA', 'ERICK'].contains(result)) {
        existing.add(result);
        await p.setStringList('custom_opts_$key', existing);
        setState(() {});
      }
    }
  }

  Future<void> _showPersonnelDialog() async {
    final list = List<String>.from(_personnel);
    final addCtrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: OmniTheme.bg900,
          title: const Text('Personal / Responsables', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Agregue los nombres del personal que apareceran en los reportes.', style: TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const Text('No hay personal registrado', style: TextStyle(color: Colors.white38, fontSize: 12))
                else
                  ...list.asMap().entries.map((e) => ListTile(
                    dense: true,
                    title: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                      onPressed: () => setDialogState(() => list.removeAt(e.key)),
                    ),
                  )),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: addCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(hintText: 'Nombre del responsable', hintStyle: TextStyle(color: Colors.white38)),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) {
                          setDialogState(() { list.add(v.trim()); addCtrl.clear(); });
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: OmniTheme.accentBlue),
                    onPressed: () {
                      if (addCtrl.text.trim().isNotEmpty) {
                        setDialogState(() { list.add(addCtrl.text.trim()); addCtrl.clear(); });
                      }
                    },
                  ),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
              child: const Text('Guardar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      setState(() => _personnel = list);
      _saveCompanyInfo();
    }
  }

  Future<void> _importProductsCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
      if (result == null || result.files.isEmpty) return;
      final file = File(result.files.single.path!);
      final lines = await file.readAsLines();
      if (lines.length < 2) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV debe tener encabezados y al menos una fila'), backgroundColor: OmniTheme.orange400));
        return;
      }
      final headers = parseCsvLine(lines[0]);
      final categoryMap = {
        'presentacion': 'Presentacion',
        'volumen': 'Volumen',
        'uso': 'Uso Terapeutico',
        'tejido': 'Tipo Tejido',
        'tipo_envio': 'Tipo Envio',
        'enviado_a': 'Enviado a',
        'pedido_por': 'Solicitado por',
      };
      int added = 0;
      for (int i = 1; i < lines.length; i++) {
        final values = parseCsvLine(lines[i]);
        if (values.length != headers.length) continue;
        for (int c = 0; c < headers.length; c++) {
          final header = headers[c].trim().toLowerCase();
          final value = values[c].trim();
          if (value.isEmpty) continue;
          String? matchedKey;
          for (final entry in categoryMap.entries) {
            if (header.contains(entry.key)) { matchedKey = entry.key; break; }
          }
          if (matchedKey == null) continue;
          final prefs = await SharedPreferences.getInstance();
          final storageKey = 'custom_opts_$matchedKey';
          final existing = prefs.getStringList(storageKey) ?? [];
          if (!existing.contains(value)) {
            existing.add(value);
            await prefs.setStringList(storageKey, existing);
            added++;
          }
        }
      }
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$added producto(s) importados'), backgroundColor: OmniTheme.green400));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al importar CSV: $e'), backgroundColor: OmniTheme.red400));
    }
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

  Future<void> _loadDriveBackupPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _driveBackupPath = prefs.getString('drive_backup_path') ?? '');
  }

  Future<void> _loadSystemPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _systemPrompt = prefs.getString('ai_system_prompt') ?? '');
  }

  Future<void> _editSystemPrompt() async {
    final ctrl = TextEditingController(text: _systemPrompt);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: OmniTheme.bg900,
        title: const Text('System Prompt del Asistente', style: TextStyle(color: OmniTheme.textPrimary)),
        content: SizedBox(
          width: 500,
          child: TextField(
            controller: ctrl,
            maxLines: 10,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Define como el asistente IA debe comportarse...',
              hintStyle: TextStyle(color: Colors.white24),
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue),
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_system_prompt', ctrl.text);
      setState(() => _systemPrompt = ctrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('System prompt guardado'),
        backgroundColor: OmniTheme.green400,
      ));
    }
  }

  Future<void> _pickDriveFolder() async {
    try {
      final result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('drive_backup_path', result);
        setState(() => _driveBackupPath = result);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ruta de backup guardada: $result'),
          backgroundColor: OmniTheme.green400,
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error: $e'),
        backgroundColor: OmniTheme.red400,
      ));
    }
  }
}
