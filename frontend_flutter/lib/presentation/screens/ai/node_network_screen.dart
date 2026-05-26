import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ai/distributed/node_manager.dart';
import '../../../theme/omni_theme.dart';

class NodeNetworkScreen extends StatefulWidget {
  const NodeNetworkScreen({super.key});

  @override
  State<NodeNetworkScreen> createState() => _NodeNetworkScreenState();
}

class _NodeNetworkScreenState extends State<NodeNetworkScreen> {
  @override
  Widget build(BuildContext context) {
    final manager = context.watch<NodeManager>();
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        title: const Text('Red de Nodos'),
        backgroundColor: OmniTheme.bg900,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: OmniTheme.bg800,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resumen de Red', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _statRow('Estado', manager.isRunning ? 'Activa' : 'Detenida', manager.isRunning ? OmniTheme.green400 : OmniTheme.red400),
                  _statRow('Nodos Totales', '${manager.nodes.length}', OmniTheme.accentBlue),
                  _statRow('Nodo Local', manager.localNode?.hostname ?? '--', OmniTheme.textPrimary),
                  _statRow('Nodo Lider', manager.leader?.hostname ?? 'Sin lider', manager.leader != null ? OmniTheme.accentBlue : OmniTheme.red400),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('NODOS REGISTRADOS', style: TextStyle(color: OmniTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (manager.nodes.isEmpty)
            Card(color: OmniTheme.bg800, child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('No hay nodos en la red. Inicia el nodo local primero.',
                  style: TextStyle(color: OmniTheme.textMuted, fontSize: 13))),
            )),
          ...manager.nodes.map((node) => Card(
            color: OmniTheme.bg800,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: node.role.name == 'leader' ? OmniTheme.accentBlue.withOpacity(0.2) : OmniTheme.bg700,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  node.role == NodeRole.leader ? Icons.star : Icons.computer,
                  color: node.role == NodeRole.leader ? OmniTheme.accentBlue : OmniTheme.textMuted,
                  size: 20,
                ),
              ),
              title: Row(children: [
                Text(node.hostname, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: node.role == NodeRole.leader ? OmniTheme.accentBlue.withOpacity(0.2) : OmniTheme.bg700,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(node.role.name.toUpperCase(), style: TextStyle(fontSize: 9, color: node.role == NodeRole.leader ? OmniTheme.accentBlue : OmniTheme.textMuted)),
                ),
                const SizedBox(width: 4),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: node.status == NodeStatus.online ? OmniTheme.green400
                        : node.status == NodeStatus.busy ? OmniTheme.orange400
                        : node.status == NodeStatus.error ? OmniTheme.red400
                        : OmniTheme.textMuted,
                  ),
                ),
              ]),
              subtitle: Text('Score: ${node.score} | ${node.platform} | Modelo: ${node.modelId}',
                  style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _statRow(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
          Text(value, style: TextStyle(color: valueColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
