import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ai/distributed/model_manager.dart';
import '../../../ai/distributed/hardware_detector.dart';
import '../../../theme/omni_theme.dart';

class ModelManagerScreen extends StatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  State<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends State<ModelManagerScreen> {
  @override
  Widget build(BuildContext context) {
    final manager = context.watch<ModelManager>();
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        title: const Text('Gestor de Modelos'),
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
                  const Text('Almacenamiento', style: TextStyle(color: OmniTheme.textPrimary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Ruta: ${manager.basePath}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
                  const SizedBox(height: 8),
                  Text('Instalados: ${manager.installedModels.length} | Activo: ${manager.activeModel?.name ?? "Ninguno"}',
                      style: const TextStyle(color: OmniTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text('MODELOS DISPONIBLES', style: TextStyle(color: OmniTheme.accentBlue, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...manager.availableModels.map((m) => _buildModelCard(manager, m)),
          if (manager.isDownloading) ...[
            const SizedBox(height: 12),
            Card(color: OmniTheme.bg800, child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: OmniTheme.accentBlue)),
                const SizedBox(width: 12),
                Expanded(child: Text(manager.downloadStatus, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 12))),
              ]),
            )),
          ],
          if (manager.installedModels.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('MODELOS INSTALADOS', style: TextStyle(color: OmniTheme.green400, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...manager.installedModels.map((m) => _buildInstalledCard(manager, m)),
          ],
        ],
      ),
    );
  }

  Widget _buildModelCard(ModelManager manager, ModelInfo model) {
    final installed = manager.installedModels.any((m) => m.id == model.id);
    return Card(
      color: OmniTheme.bg800,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(model.name, style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14)),
        subtitle: Text('${model.format.toUpperCase()} | ${(model.sizeMB / 1024).toStringAsFixed(1)} GB | ${model.backend}',
            style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
        trailing: installed
            ? const Icon(Icons.check_circle, color: OmniTheme.green400, size: 20)
            : ElevatedButton.icon(
                icon: const Icon(Icons.download, size: 14),
                label: const Text('Instalar', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(backgroundColor: OmniTheme.accentBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4)),
                onPressed: manager.isDownloading ? null : () => manager.downloadModel(model),
              ),
        dense: true,
      ),
    );
  }

  Widget _buildInstalledCard(ModelManager manager, ModelInfo model) {
    final isActive = manager.activeModel?.id == model.id;
    return Card(
      color: isActive ? OmniTheme.accentBlue.withOpacity(0.1) : OmniTheme.bg800,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(isActive ? Icons.check_circle : Icons.check, color: isActive ? OmniTheme.accentBlue : OmniTheme.green400, size: 20),
        title: Text(model.name, style: TextStyle(color: OmniTheme.textPrimary, fontSize: 14, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
        subtitle: Text('Version ${model.version} | ${model.backend}', style: const TextStyle(color: OmniTheme.textMuted, fontSize: 11)),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!isActive)
            TextButton(
              onPressed: () => manager.setActiveModel(model.id),
              child: const Text('Activar', style: TextStyle(fontSize: 11, color: OmniTheme.accentBlue)),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: OmniTheme.red400),
            onPressed: () => manager.deleteModel(model.id),
          ),
        ]),
      ),
    );
  }
}
