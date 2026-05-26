import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/license_service.dart';
import '../../theme/omni_theme.dart';
import 'login_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _activate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _error = 'Ingresa la clave de activacion');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final license = context.read<LicenseService>();
      final ok = await license.activate(key);
      if (ok && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else if (mounted) {
        setState(() { _loading = false; _error = license.lastError ?? 'Clave incorrecta'; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.vpn_key, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 24),
                const Text('Activacion de Licencia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
                const SizedBox(height: 8),
                Text('Ingresa la clave de activacion proporcionada por el administrador', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                const SizedBox(height: 32),
                TextField(
                  controller: _keyController,
                  style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Clave de activacion',
                    hintStyle: TextStyle(color: OmniTheme.textMuted.withOpacity(0.5), fontSize: 14),
                    filled: true, fillColor: OmniTheme.bg900,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    suffixIcon: Icon(Icons.lock_outline, color: OmniTheme.textMuted, size: 18),
                  ),
                  onSubmitted: (_) => _activate(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: OmniTheme.red400.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      Icon(Icons.error_outline, color: OmniTheme.red400, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: TextStyle(color: OmniTheme.red400, fontSize: 11))),
                    ]),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _activate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: OmniTheme.accentBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _loading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Activar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Text('La app verifica la licencia contra GitHub periodicamente', style: TextStyle(fontSize: 9, color: OmniTheme.textMuted.withOpacity(0.6))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
