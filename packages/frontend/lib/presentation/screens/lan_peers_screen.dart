import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../sync/lan_discovery_service.dart';

class LanPeersScreen extends ConsumerWidget {
  const LanPeersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lanDiscoveryServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos en Red')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: state.isRunning ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
            child: Row(
              children: [
                Icon(
                  state.isRunning ? Icons.wifi : Icons.wifi_off,
                  color: state.isRunning ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 8),
                Text(
                  state.isRunning ? 'Descubrimiento activo' : 'Descubrimiento detenido',
                  style: TextStyle(
                    color: state.isRunning ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: state.peers.isEmpty
                ? const Center(child: Text('No se encontraron dispositivos'))
                : ListView.builder(
                    itemCount: state.peers.length,
                    itemBuilder: (_, i) {
                      final peer = state.peers[i];
                      return ListTile(
                        leading: const Icon(Icons.devices),
                        title: Text(peer.hostname),
                        subtitle: Text('${peer.ip}:${peer.port}'),
                        trailing: Text(peer.deviceId, style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
