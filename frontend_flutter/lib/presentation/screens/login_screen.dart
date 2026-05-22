import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../security/auth_service.dart';
import '../../services/user_service.dart';
import '../../theme/omni_theme.dart';
import 'main_scaffold.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController(text: 'usr-admin');
  String _errorMessage = '';
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
    _pinController.dispose();
    _userIdController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    setState(() => _errorMessage = '');
    final pin = _pinController.text;
    final userId = _userIdController.text;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';

    final authService = context.read<AuthService>();
    final success = await authService.login(userId, pin, deviceId);

    if (success && mounted) {
      context.read<UserService>().loadFromAuth(authService);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const MainScaffold(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      setState(() => _errorMessage = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      body: Stack(
        children: [
          const _BackgroundEffect(),
          Center(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  width: 380,
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: OmniTheme.accentBlue.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.biotech, color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 16),
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [OmniTheme.accentBlue, OmniTheme.accentIndigo],
                            ).createShader(bounds),
                            child: const Text(
                              'BIOLAB',
                              style: TextStyle(
                                fontFamily: 'Outfit',
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                                color: Colors.white,
                                letterSpacing: 4,
                              ),
                            ),
                          ),
                          const Text(
                            'LABSYNC ENTERPRISE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: OmniTheme.textMuted,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          TextField(
                            controller: _userIdController,
                            style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14),
                            decoration: const InputDecoration(
                              labelText: 'USUARIO',
                              prefixIcon: Icon(Icons.person_outline, size: 18, color: OmniTheme.textMuted),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _pinController,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            maxLength: 4,
                            style: const TextStyle(
                              color: OmniTheme.textPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 12,
                            ),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'PIN',
                              counterText: '',
                              prefixIcon: Icon(Icons.lock_outline, size: 18, color: OmniTheme.textMuted),
                            ),
                          ),
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: OmniTheme.red400.withOpacity(0.1),
                                border: Border.all(color: OmniTheme.red400.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline, size: 16, color: OmniTheme.red400),
                                  const SizedBox(width: 8),
                                  Text(
                                    _errorMessage,
                                    style: const TextStyle(color: OmniTheme.red400, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Consumer<AuthService>(
                            builder: (context, auth, _) => SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: auth.isLoading ? null : _attemptLogin,
                                child: auth.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('INICIAR SESION'),
                              ),
                            ),
                          ),
                        ],
                      ),
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

class _BackgroundEffect extends StatelessWidget {
  const _BackgroundEffect();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _RadialGradientPainter(),
    );
  }
}

class _RadialGradientPainter extends CustomPainter {
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
        OmniTheme.accentBlue.withOpacity(0.05),
        Colors.transparent,
      ],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
