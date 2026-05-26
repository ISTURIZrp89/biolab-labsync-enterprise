import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ai/ai_service.dart';
import '../../../ai/distributed/hardware_detector.dart';
import '../../../ai/distributed/model_manager.dart';
import '../../../ai/distributed/node_manager.dart';
import '../../../ai/distributed/shared_memory.dart';
import '../../../theme/omni_theme.dart';

class AiDashboardScreen extends StatefulWidget {
  const AiDashboardScreen({super.key});

  @override
  State<AiDashboardScreen> createState() => _AiDashboardScreenState();
}

class _AiDashboardScreenState extends State<AiDashboardScreen> {
  HardwareProfile? _hw;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _detectHardware();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) => setState(() {}));
  }

  Future<void> _detectHardware() async {
    _hw = await HardwareDetector.detect();
    setState(() {});
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiService>();
    final models = context.watch<ModelManager>();
    final nodes = context.watch<NodeManager>();
    final memory = context.watch<SharedMemory>();

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        title: const Text('Supervisor AI'),
        backgroundColor: OmniTheme.bg900,
        actions: [
          Switch(
            value: ai.enabled,
            activeColor: OmniTheme.accentBlue,
            onChanged: (v) => ai.enabled = v,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection('Hardware Detectado', Icons.memory, [
            _row('RAM', '${_hw?.ramMB ?? 0} MB'),
            _row('CPU', '${_hw?.cpuCores ?? 0} nucleos (${_hw?.cpuArch ?? ''})'),
            _row('VRAM', '${_hw?.vramMB ?? 0} MB'),
            _row('GPU', _hw?.gpuName ?? 'No detectada'),
            _row('Tier', _hw?.tier ?? '--'),
            _row('Score', '${_hw?.score ?? 0}'),
            _row('Apple Silicon', _hw?.isAppleSilicon == true ? 'Si' : 'No'),
            _row('Metal', _hw?.hasMetal == true ? 'Disponible' : 'No'),
          ]),
          const SizedBox(height: 12),
          _buildSection('Estado del Supervisor', Icons.psychology, [
            _row('Texto Predictivo', ai.enabled ? 'Activado' : 'Desactivado'),
            _row('Modelo Activo', models.activeModel?.name ?? 'Ninguno'),
            _row('Modelos Instalados', '${models.installedModels.length}'),
            _row('Nodos en Red', '${nodes.nodes.length}'),
            _row('Nodo Lider', nodes.leader?.hostname ?? '--'),
            _row('Entradas Memoria', '${memory.entryCount}'),
            _row('Tareas Pendientes', '${memory.pendingTasks}'),
          ]),
          const SizedBox(height: 12),
          _buildSection('Backend Recomendado', Icons.settings, [
            _row('Backend', HardwareDetector.recommendedBackend(_hw ?? HardwareProfile())),
            _row('Modelo Recomendado', HardwareDetector.recommendedModel(_hw ?? HardwareProfile())),
          ]),
          const SizedBox(height: 12),
          Card(
            color: OmniTheme.bg800,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('Red Distribuida', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    icon: Icon(nodes.isRunning ? Icons.stop : Icons.play_arrow, size: 16),
                    label: Text(nodes.isRunning ? 'Detener Nodo' : 'Iniciar Nodo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nodes.isRunning ? OmniTheme.red400 : OmniTheme.green400,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      if (nodes.isRunning) {
                        nodes.stop();
                      } else {
                        nodes.start(
                          hostname: _hw?.cpuArch ?? 'local',
                          port: 9753,
                          score: _hw?.score ?? 0,
                          platform: _hw?.isAppleSilicon == true ? 'macOS-arm64' : 'windows',
                          modelId: models.activeModel?.id ?? '',
                        );
                      }
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Card(
      color: OmniTheme.bg800,
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: Icon(icon, color: OmniTheme.accentBlue, size: 20),
        title: Text(title, style: const TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
        children: children.map((c) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: c,
        )).toList(),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: OmniTheme.textMuted, fontSize: 13)),
          Text(value, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
