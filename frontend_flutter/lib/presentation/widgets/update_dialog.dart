import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/update_service.dart';
import '../../theme/omni_theme.dart';

class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final updateService = context.watch<UpdateService>();

    return Dialog(
      backgroundColor: OmniTheme.bg950,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: OmniTheme.primary.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update,
                size: 48,
                color: OmniTheme.primary,
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
                      backgroundColor: OmniTheme.primary,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Actualizar', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
