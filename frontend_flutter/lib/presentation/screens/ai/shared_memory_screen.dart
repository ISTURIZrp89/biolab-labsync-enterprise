import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ai/distributed/shared_memory.dart';
import '../../../theme/omni_theme.dart';

class SharedMemoryScreen extends StatefulWidget {
  const SharedMemoryScreen({super.key});

  @override
  State<SharedMemoryScreen> createState() => _SharedMemoryScreenState();
}

class _SharedMemoryScreenState extends State<SharedMemoryScreen> {
  final _keyCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  @override
  void dispose() {
    _keyCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memory = context.watch<SharedMemory>();
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        title: const Text('Memoria Compartida'),
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
                  const Text('Estado', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _row('Entradas', '${memory.entryCount}'),
                  _row('Bloqueado', memory.isLocked ? 'Si' : 'No'),
                  _row('Nodo Lider', memory.leaderNodeId ?? '--'),
                  _row('Tareas en cola', '${memory.pendingTasks}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: OmniTheme.bg800,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Agregar Entrada', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _keyCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'Clave',
                      labelStyle: TextStyle(color: OmniTheme.textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: OmniTheme.accentBlue)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valueCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Valor',
                      labelStyle: TextStyle(color: OmniTheme.textMuted),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: OmniTheme.bg700)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: OmniTheme.accentBlue)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save, size: 16),
                    label: const Text('Guardar en Memoria'),
                    style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (_keyCtrl.text.isEmpty) return;
                      await memory.setEntry(_keyCtrl.text, _valueCtrl.text, 'admin');
                      _keyCtrl.clear();
                      _valueCtrl.clear();
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Entrada guardada')));
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('ENTRADAS ALMACENADAS', style: TextStyle(color: OmniTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (memory.store.isEmpty)
            Card(color: OmniTheme.bg800, child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(child: Text('Memoria vacia. Agrega entradas desde el panel superior.',
                  style: TextStyle(color: OmniTheme.textMuted, fontSize: 13))),
            )),
          ...memory.store.entries.map((e) => Card(
            color: OmniTheme.bg800,
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(e.key, style: const TextStyle(color: OmniTheme.accentBlue, fontSize: 13, fontWeight: FontWeight.w500)),
              subtitle: Text(e.value.value, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 12)),
              trailing: Text('v${e.value.version}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 10)),
            ),
          )),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13)),
        ],
      ),
    );
  }
}
