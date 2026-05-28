import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/auth_service.dart';
import '../../core/theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
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
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
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
        {'id': 'usr-admin', 'nombre': 'Administrador', 'rol': 'ADMIN'},
        {'id': 'usr-jefe', 'nombre': 'Dr. Alberto Parra Barrera', 'rol': 'JEFE'},
        {'id': 'usr-t1', 'nombre': 'Biol. Maria Guadalupe Ramirez Padilla', 'rol': 'LABORATORIO'},
        {'id': 'usr-auditor', 'nombre': 'Auditor Externo', 'rol': 'AUDITOR'},
        {'id': 'usr-dueno', 'nombre': 'Director General', 'rol': 'DUENO'},
      ];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _tryOfflineLogin(String userId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('offline_pins');
    if (cached == null) return false;
    try {
      final pins = jsonDecode(cached) as Map<String, dynamic>;
      return pins[userId] == pin;
    } catch (_) {
      return false;
    }
  }

  Future<void> _cachePinsForOffline(String userId, String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('offline_pins');
    final pins = cached != null ? jsonDecode(cached) as Map<String, dynamic> : <String, dynamic>{};
    pins[userId] = pin;
    await prefs.setString('offline_pins', jsonEncode(pins));
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

    final authService = ref.read(authProvider.notifier);
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? 'dev-unknown';
    final success = await authService.login(_selectedUserId!, pin, deviceId);

    if (success && mounted) {
      await _cachePinsForOffline(_selectedUserId!, pin);
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      final offlineOk = await _tryOfflineLogin(_selectedUserId!, pin);
      if (offlineOk && mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      } else {
        setState(() => _errorMessage = 'PIN incorrecto');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.isLoading;
    final selectedUser = _selectedUserId != null
        ? _users.where((u) => u['id'].toString() == _selectedUserId).firstOrNull
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
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
                    color: const Color(0xFF1A1A2E),
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
                                colors: [Color(0xFF6750A4), Color(0xFF7C4DFF)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.biotech,
                                color: Colors.white, size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'BIOLAB',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: Colors.white,
                              letterSpacing: 4,
                            ),
                          ),
                          const Text(
                            'LABSYNC ENTERPRISE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white54,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          else ...[
                            DropdownButtonFormField<String>(
                              value: _selectedUserId,
                              items: _users
                                  .map(
                                    (u) => DropdownMenuItem(
                                      value: u['id'].toString(),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.person,
                                              size: 16,
                                              color: Color(0xFF7C4DFF)),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                u['nombre'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white),
                                              ),
                                              Text(
                                                u['rol'] ?? '',
                                                style: const TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.white54),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _selectedUserId = v),
                              dropdownColor: const Color(0xFF16213E),
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.white),
                              decoration: const InputDecoration(
                                labelText: 'USUARIO',
                                prefixIcon: Icon(Icons.person_outline,
                                    size: 18, color: Colors.white54),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _pinController,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 4,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 12,
                              ),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                labelText: 'PIN',
                                counterText: '',
                                prefixIcon: Icon(Icons.lock_outline,
                                    size: 18, color: Colors.white54),
                              ),
                            ),
                          ],
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.1),
                                border: Border.all(
                                    color: Colors.red.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline,
                                      size: 16, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(_errorMessage,
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _attemptLogin,
                              child: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Text('INICIAR SESION'),
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
        const Color(0xFF6750A4).withOpacity(0.08),
        const Color(0xFF7C4DFF).withOpacity(0.03),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0, 0.3, 0.6, 1],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
