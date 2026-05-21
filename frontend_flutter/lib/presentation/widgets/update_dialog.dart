import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();

    return WillPopScope(
      onWillPop: () async => !updateService.isMandatory && !updateService.isDownloading && !updateService.isInstalling,
      child: Dialog(
        backgroundColor: const Color(0xFF001830),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (updateService.isDownloading || updateService.isInstalling) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004A99).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: updateService.isInstalling
                      ? const Icon(Icons.install_mobile, size: 48, color: Color(0xFF004A99))
                      : const SizedBox(
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF004A99)),
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  updateService.isInstalling ? 'Instalando...' : 'Descargando...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  updateService.statusMessage,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: updateService.downloadProgress,
                  backgroundColor: Colors.white.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF004A99)),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  '${(updateService.downloadProgress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                ),
              ] else if (updateService.hasUpdate) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF004A99).withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update,
                    size: 48,
                    color: Color(0xFF004A99),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Actualizacion Disponible',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'v${updateService.currentVersion} -> v${updateService.latestVersion}',
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    updateService.releaseNotes,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                    textAlign: TextAlign.left,
                  ),
                ),
                if (updateService.isMandatory) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'ACTUALIZACION OBLIGATORIA',
                      style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (!updateService.isMandatory)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.white.withOpacity(0.3)),
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Despues', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    if (!updateService.isMandatory) const SizedBox(width: 12),
                    Expanded(
                      flex: updateService.isMandatory ? 1 : 1,
                      child: ElevatedButton(
                        onPressed: () => updateService.installNow(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF004A99),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Actualizar Ahora', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const Icon(Icons.check_circle, size: 48, color: Colors.green),
                const SizedBox(height: 16),
                const Text(
                  'La aplicacion esta actualizada',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF004A99),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('OK', style: TextStyle(color: Colors.white)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
