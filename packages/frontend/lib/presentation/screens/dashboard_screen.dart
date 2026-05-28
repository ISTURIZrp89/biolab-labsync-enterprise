import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';
import '../../sync/sync_engine.dart';
import 'form_entry_screen.dart';
import 'users_screen.dart';
import 'audit_log_screen.dart';
import 'closure_screen.dart';
import 'templates_screen.dart';
import 'sync_status_screen.dart';
import 'settings_screen.dart';
import 'backup_screen.dart';
import 'lan_peers_screen.dart';
import 'reports_screen.dart';
import 'calendar_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncEngineProvider);
    final auth = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.currentUser?.nombre ?? 'BioLab LABSYNC'),
        actions: [
          _SyncIndicator(syncState: syncState),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Salir',
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      drawer: _buildDrawer(context, ref),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.biotech, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Dashboard', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Sync: ${syncState.syncCount} exitosos, ${syncState.failedCount} fallidos',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (syncState.lastSync != null)
              Text('Ultima sync: ${syncState.lastSync!.toLocal()}'),
            const SizedBox(height: 32),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _quickCard(context, 'Registrar', Icons.edit_note, const FormEntryScreen()),
                _quickCard(context, 'Calendario', Icons.calendar_month, const CalendarScreen()),
                _quickCard(context, 'Usuarios', Icons.group, const UsersScreen()),
                _quickCard(context, 'Cierres', Icons.lock, const ClosureScreen()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.biotech, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                const Text('BioLab LABSYNC', style: TextStyle(color: Colors.white, fontSize: 18)),
                Text(authState.currentUser?.nombre ?? '', style: const TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          _drawerItem(Icons.edit_note, 'Registrar entrada', () => _navigate(context, const FormEntryScreen())),
          _drawerItem(Icons.calendar_month, 'Calendario', () => _navigate(context, const CalendarScreen())),
          _drawerItem(Icons.group, 'Usuarios', () => _navigate(context, const UsersScreen())),
          _drawerItem(Icons.lock, 'Cierres', () => _navigate(context, const ClosureScreen())),
          _drawerItem(Icons.description, 'Plantillas', () => _navigate(context, const TemplatesScreen())),
          _drawerItem(Icons.sync, 'Sincronizacion', () => _navigate(context, const SyncStatusScreen())),
          _drawerItem(Icons.receipt_long, 'Reportes', () => _navigate(context, const ReportsScreen())),
          _drawerItem(Icons.backup, 'Respaldos', () => _navigate(context, const BackupScreen())),
          _drawerItem(Icons.wifi, 'Dispositivos LAN', () => _navigate(context, const LanPeersScreen())),
          _drawerItem(Icons.history, 'Auditoria', () => _navigate(context, const AuditLogScreen())),
          const Divider(),
          _drawerItem(Icons.settings, 'Configuracion', () => _navigate(context, const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }

  Widget _quickCard(BuildContext context, String label, IconData icon, Widget screen) {
    return SizedBox(
      width: 140,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _navigate(context, screen),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 8),
                Text(label, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _SyncIndicator extends StatelessWidget {
  final SyncState syncState;

  const _SyncIndicator({required this.syncState});

  @override
  Widget build(BuildContext context) {
    final color = syncState.isSyncing
        ? Colors.orange
        : syncState.isOnline
            ? Colors.green
            : Colors.red;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Tooltip(
        message: syncState.isSyncing
            ? 'Sincronizando...'
            : syncState.isOnline
                ? 'Conectado'
                : 'Sin conexion',
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
