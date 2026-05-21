import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import '../../sync/sync_engine.dart';

String _getPlatformName() {
  if (kIsWeb) return 'Web';
  if (Platform.isWindows) return 'Windows';
  if (Platform.isMacOS) return 'macOS';
  if (Platform.isLinux) return 'Linux (Ubuntu)';
  if (Platform.isAndroid) return 'Android';
  if (Platform.isIOS) return 'iOS (iPhone/iPad)';
  return 'Unknown';
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
  String _appVersion = '7.1.0';
  bool _isOnline = false;
  int _pendingSync = 0;
  String _lastSync = 'Nunca';
  bool _autoSync = true;

  @override
  void initState() {
    super.initState();
    _platform = _getPlatformName();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'Unknown';
    final savedUrl = prefs.getString('backend_url');
    final autoSync = prefs.getBool('auto_sync') ?? true;
    final lastSync = prefs.getString('last_sync_timestamp');

    setState(() {
      _deviceId = deviceId;
      _backendUrl = savedUrl ?? 'http://localhost:8000';
      _autoSync = autoSync;
      _lastSync = lastSync != null ? _formatTimestamp(lastSync) : 'Nunca';
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
    try {
      final res = await http.get(
        Uri.parse('$_backendUrl/api/updates/check?current_version=$_appVersion'),
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) {
          if (data['has_update'] == true) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF001830),
                title: const Text('Actualizacion Disponible', style: TextStyle(color: Colors.white)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Version: ${data['latest_version']}', style: const TextStyle(color: Colors.white70)),
                    const SizedBox(height: 8),
                    Text(data['release_notes'] ?? '', style: const TextStyle(color: Colors.white54)),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Descargando actualizacion...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004A99)),
                    child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('La aplicacion esta actualizada')),
            );
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo verificar actualizaciones')),
        );
      }
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
        backgroundColor: const Color(0xFF001830),
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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF004A99)),
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
            colors: [Color(0xFF001020), Color(0xFF000810)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSection(
              'Estado del Sistema',
              [
                _buildInfoRow('Estado', _isOnline ? 'En linea' : 'Desconectado', Icons.wifi),
                _buildInfoRow('Plataforma', _platform, Icons.devices),
                _buildInfoRow('Ultima Sincronizacion', _lastSync, Icons.sync),
                _buildInfoRow('Pendientes', '$_pendingSync registros', Icons.pending),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Dispositivo',
              [
                _buildInfoRow('Device ID', _deviceId, Icons.fingerprint),
                _buildInfoRow('Version App', _appVersion, Icons.info),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Sincronizacion',
              [
                SwitchListTile(
                  title: const Text('Sincronizacion Automatica', style: TextStyle(color: Colors.white)),
                  subtitle: Text(
                    _autoSync ? 'Cada 5 minutos' : 'Desactivada',
                    style: TextStyle(color: Colors.white.withOpacity(0.5)),
                  ),
                  value: _autoSync,
                  onChanged: _toggleAutoSync,
                  activeColor: const Color(0xFF004A99),
                ),
                ListTile(
                  leading: const Icon(Icons.sync, color: Color(0xFF004A99)),
                  title: const Text('Sincronizar Ahora', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    final sync = context.read<SyncEngine>();
                    final success = await sync.synchronize();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(success
                            ? 'Sincronizacion completada'
                            : 'Error al sincronizar')),
                      );
                      _loadSettings();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Servidor',
              [
                ListTile(
                  leading: const Icon(Icons.dns, color: Color(0xFF004A99)),
                  title: const Text('URL del Servidor', style: TextStyle(color: Colors.white)),
                  subtitle: Text(_backendUrl, style: TextStyle(color: Colors.white.withOpacity(0.5))),
                  trailing: const Icon(Icons.edit, color: Colors.white54),
                  onTap: _changeBackendUrl,
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Actualizaciones',
              [
                ListTile(
                  leading: const Icon(Icons.system_update, color: Color(0xFF004A99)),
                  title: const Text('Buscar Actualizaciones', style: TextStyle(color: Colors.white)),
                  onTap: _checkForUpdates,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: Column(
                children: [
                  Text(
                    'LABSYNC Enterprise v$_appVersion',
                    style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Compatible: Windows, macOS, Linux, iOS, Android',
                    style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      color: const Color(0xFF001830),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
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
      leading: Icon(icon, color: const Color(0xFF004A99), size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      subtitle: Text(value, style: TextStyle(color: Colors.white.withOpacity(0.5))),
    );
  }
}
