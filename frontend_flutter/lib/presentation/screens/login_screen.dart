import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../security/auth_service.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController(text: 'usr-admin');
  String _errorMessage = '';

  Future<void> _attemptLogin() async {
    setState(() => _errorMessage = '');
    final pin = _pinController.text;
    final userId = _userIdController.text;
    final prefs = await SharedPreferences.getInstance();
    final deviceId = prefs.getString('device_id') ?? '';

    final authService = context.read<AuthService>();
    final success = await authService.login(userId, pin, deviceId);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
      );
    } else {
      setState(() => _errorMessage = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001020),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔬', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text('BIOLAB', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24, letterSpacing: 4)),
              const Text('LABSYNC ENTERPRISE', style: TextStyle(color: Colors.white60, fontSize: 12)),
              const SizedBox(height: 24),
              TextField(
                controller: _userIdController,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: const InputDecoration(
                  labelText: 'Usuario',
                  labelStyle: TextStyle(color: Colors.white38),
                  prefixIcon: Icon(Icons.person, color: Colors.white60),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                decoration: const InputDecoration(
                  hintText: 'PIN de 4 digitos',
                  hintStyle: TextStyle(color: Colors.white38),
                  counterText: "",
                  prefixIcon: Icon(Icons.lock, color: Colors.white60),
                ),
              ),
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
              ],
              const SizedBox(height: 24),
              Consumer<AuthService>(
                builder: (context, auth, _) => ElevatedButton(
                  onPressed: auth.isLoading ? null : _attemptLogin,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    backgroundColor: const Color(0xFF004A99),
                  ),
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Iniciar Sesion', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _userIdController.dispose();
    super.dispose();
  }
}
