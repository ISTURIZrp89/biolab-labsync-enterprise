import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../security/auth_service.dart';
import '../../services/user_service.dart';
import '../../services/audit_service.dart';
import '../../theme/omni_theme.dart';
import 'main_scaffold.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _pinController = TextEditingController();
  String _errorMessage = '';
  String? _selectedUserId;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
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
    _loadUsers();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');
    if (raw != null && raw != '[]') {
      try {
        final list = jsonDecode(raw) as List;
        _users = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }
    if (_users.isEmpty) {
      _users = [
        {'id': '1', 'nombre': 'Admin', 'pin': '1234', 'rol': 'Admin', 'cargo_operativo': 'ADMINISTRADOR', 'area': '', 'supervisor': '', 'firma': ''},
        {'id': '2', 'nombre': 'Jefe', 'pin': '0000', 'rol': 'Supervisor', 'cargo_operativo': 'JEFE DE LABORATORIO', 'area': '', 'supervisor': '', 'firma': ''},
        {'id': '3', 'nombre': 'Tecnico', 'pin': '1111', 'rol': 'Laboratorio', 'cargo_operativo': 'TÉCNICO', 'area': '', 'supervisor': '', 'firma': ''},
        {'id': '4', 'nombre': 'Auditor', 'pin': '2222', 'rol': 'Auditor', 'cargo_operativo': 'QFB', 'area': '', 'supervisor': '', 'firma': ''},
        {'id': '5', 'nombre': 'Director General', 'pin': '3333', 'rol': 'Dueno', 'cargo_operativo': 'DIRECTOR GENERAL', 'area': '', 'supervisor': '', 'firma': ''},
      ];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _attemptLogin() async {
    setState(() => _errorMessage = '');
    final pin = _pinController.text;
    if (_selectedUserId == null) {
      setState(() => _errorMessage = 'Selecciona un usuario');
      return;
    }
    if (pin.isEmpty) {
      setState(() => _errorMessage = 'Ingresa tu PIN');
      return;
    }

    final authService = context.read<AuthService>();
    final success = await authService.login(_selectedUserId!, pin, '');

    if (success && mounted) {
      context.read<UserService>().loadFromAuth(authService);
      try {
        final user = authService.currentUser;
        if (user != null) {
          context.read<AuditService>().log(
            action: 'Inicio de sesion',
            type: 'login',
            userId: user.id,
            userName: user.nombre,
            details: 'Login exitoso desde ${_selectedUserId}',
            deviceId: _selectedUserId,
          );
        }
      } catch (_) {}
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
    final selectedUser = _selectedUserId != null
        ? _users.where((u) => u['id'].toString() == _selectedUserId).firstOrNull
        : null;

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
                  width: 400,
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [OmniTheme.primary, OmniTheme.secondary],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: OmniTheme.primary.withOpacity(0.3),
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
                              colors: [OmniTheme.primary, OmniTheme.primaryLight],
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
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: _selectedUserId,
                              items: _users.map((u) => DropdownMenuItem(
                                value: u['id'].toString(),
                                child: Row(children: [
                                  Icon(Icons.person, size: 16, color: OmniTheme.accentBlue),
                                  const SizedBox(width: 8),
                                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(u['nombre'] ?? '', style: const TextStyle(fontSize: 14, color: Colors.white)),
                                    Text(u['rol'] ?? '', style: TextStyle(fontSize: 10, color: OmniTheme.textMuted)),
                                  ]),
                                ]),
                              )).toList(),
                              onChanged: (v) => setState(() => _selectedUserId = v),
                              dropdownColor: OmniTheme.bg800,
                              style: const TextStyle(fontSize: 14, color: Colors.white),
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
                          ],
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
                                  Text(_errorMessage, style: const TextStyle(color: OmniTheme.red400, fontSize: 12)),
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
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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
        OmniTheme.primary.withOpacity(0.08),
        OmniTheme.secondary.withOpacity(0.03),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0, 0.3, 0.6, 1],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);

    final rect2 = Rect.fromCenter(
      center: Offset(size.width * 0.2, size.height * 0.5),
      width: size.width * 0.6,
      height: size.height * 0.6,
    );
    final gradient2 = RadialGradient(
      center: Alignment.center,
      radius: 0.5,
      colors: [
        OmniTheme.tertiary.withOpacity(0.04),
        Colors.transparent,
      ],
    );
    final paint2 = Paint()..shader = gradient2.createShader(rect2);
    canvas.drawRect(rect2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
