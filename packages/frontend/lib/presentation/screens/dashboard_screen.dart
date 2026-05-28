import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart' show authProvider;
import '../../sync/sync_engine.dart';

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
          TextButton.icon(
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              Navigator.pushReplacementNamed(context, '/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Salir'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.biotech, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Dashboard - BioLab LABSYNC Enterprise',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Sync: ${syncState.syncCount} exitosos, ${syncState.failedCount} fallidos',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (syncState.lastSync != null)
              Text(
                'Ultima sync: ${syncState.lastSync!.toLocal()}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
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
