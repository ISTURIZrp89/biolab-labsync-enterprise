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

class _ActivationScreenState extends State<ActivationScreen> with SingleTickerProviderStateMixin {
  final _keyController = TextEditingController();
  bool _loading = false;
  String? _error;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _animController.dispose();
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
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ));
      } else if (mounted) {
        setState(() { _loading = false; _error = license.lastError ?? 'Clave incorrecta'; });
      }
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = 'Error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final license = context.watch<LicenseService>();

    if (license.decommissioned) {
      return Scaffold(
        backgroundColor: OmniTheme.bg950,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: OmniTheme.error.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.gpp_bad, color: OmniTheme.error, size: 36),
              ),
              const SizedBox(height: 24),
              const Text('Equipo Dado de Baja', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
              const SizedBox(height: 8),
              Text(
                'Este equipo ha sido desactivado por el administrador.\n'
                'Los datos locales han sido respaldados y eliminados.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: OmniTheme.textMuted),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 44,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OmniTheme.textMuted,
                    side: BorderSide(color: OmniTheme.textMuted.withOpacity(0.3)),
                  ),
                  child: const Text('Contacta al administrador', style: TextStyle(fontSize: 12)),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    if (license.activated) {
      return Scaffold(
        backgroundColor: OmniTheme.bg950,
        body: Center(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [OmniTheme.success, OmniTheme.primary]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 36),
              ),
              const SizedBox(height: 24),
              Text('Licencia Activa - ${license.branch?.toUpperCase() ?? ""}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
              const SizedBox(height: 8),
              const Text('Redirigiendo...', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      body: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: _ActivationBgPainter(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [OmniTheme.primary, OmniTheme.secondary]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: OmniTheme.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: const Icon(Icons.vpn_key, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 24),
                        const Text('Activacion de Licencia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: OmniTheme.textPrimary)),
                        const SizedBox(height: 8),
                        Text('Ingresa la clave de activacion proporcionada por el administrador\nFormato: LABSYNC-SUCURSAL-XXXX-XXXX', style: TextStyle(fontSize: 12, color: OmniTheme.textMuted)),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _keyController,
                          style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'LABSYNC-SUCURSAL-XXXX-XXXX',
                            hintStyle: TextStyle(color: OmniTheme.textMuted.withOpacity(0.5), fontSize: 14),
                            filled: true, fillColor: OmniTheme.bg900,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixIcon: Icon(Icons.lock_outline, color: OmniTheme.textMuted, size: 18),
                          ),
                          onSubmitted: (_) => _activate(),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: OmniTheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                            child: Row(children: [
                              Icon(Icons.error_outline, color: OmniTheme.error, size: 16),
                              const SizedBox(width: 8),
                              Expanded(child: Text(_error!, style: TextStyle(color: OmniTheme.error, fontSize: 11))),
                            ]),
                          ),
                        ],
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity, height: 44,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _activate,
                            child: _loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Activar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('La app verifica la licencia contra GitHub cada 10 min', style: TextStyle(fontSize: 9, color: OmniTheme.textMuted.withOpacity(0.6))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, 0),
      width: size.width,
      height: size.height,
    );
    final gradient = RadialGradient(
      center: Alignment.topCenter,
      radius: 0.8,
      colors: [
        OmniTheme.primary.withOpacity(0.08),
        OmniTheme.secondary.withOpacity(0.03),
        Colors.transparent,
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
