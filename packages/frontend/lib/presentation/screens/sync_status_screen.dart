import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/sync_engine.dart';

class SyncStatusScreen extends ConsumerWidget {
  const SyncStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(syncEngineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de Sincronizacion')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Estado', state.isSyncing ? 'Sincronizando...' : 'Inactivo'),
            _row('Conexion', state.isOnline ? 'Conectado' : 'Sin conexion'),
            _row('Sincronizaciones exitosas', '${state.syncCount}'),
            _row('Fallos', '${state.failedCount}'),
            if (state.lastSync != null)
              _row('Ultima sync', state.lastSync!.toLocal().toString()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => ref.read(syncEngineProvider.notifier).synchronize(),
                icon: const Icon(Icons.sync),
                label: const Text('Sincronizar ahora'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}
