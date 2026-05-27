import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';

class AuthService extends ChangeNotifier {
  final AuthRepository _authRepository;
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  DateTime? _sessionStart;
  Timer? _sessionTimer;
  Timer? _inactivityTimer;
  int _lastActivityMs = 0;

  static const int sessionTimeoutMinutes = 480;
  static const int inactivityTimeoutMinutes = 30;

  AuthService(this._authRepository);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  DateTime? get sessionStart => _sessionStart;
  int get sessionDurationMinutes => _sessionStart != null
      ? DateTime.now().difference(_sessionStart!).inMinutes
      : 0;

  bool get isAdmin => _currentUser?.rol == 'ADMIN';
  bool get isSupervisor => _currentUser?.rol == 'JEFE' || _currentUser?.rol == 'ADMIN' || _currentUser?.rol == 'DUEÑO';
  bool get isAuditor => _currentUser?.rol == 'AUDITOR';
  bool get isOwner => _currentUser?.rol == 'DUEÑO' || _currentUser?.rol == 'ADMIN';
  bool get canClose => isAdmin || isSupervisor;
  bool get canReopen => isAdmin || isOwner;
  bool get canManageUsers => isAdmin || isOwner;
  bool get canManageClosures => isAdmin || isSupervisor;
  bool get canViewReports => isAdmin || isSupervisor || isAuditor || isOwner;
  bool get canUseAI => isAuthenticated && !isAuditor;
  bool get canExport => isAdmin || isOwner || isSupervisor;
  bool get canManageModels => isAdmin || isOwner;

  static String _mapRol(String rol) {
    final upper = rol.toUpperCase();
    if (upper == 'ADMIN') return 'ADMIN';
    if (upper == 'SUPERVISOR' || upper == 'JEFE') return 'JEFE';
    if (upper == 'LABORATORIO' || upper == 'TÉCNICO' || upper == 'TECNICO') return 'LABORATORIO';
    if (upper == 'AUDITOR') return 'AUDITOR';
    if (upper == 'DUENO' || upper == 'DUEÑO' || upper == 'OWNER') return 'DUEÑO';
    return 'LABORATORIO';
  }

  static const List<String> rolesSistema = ['ADMIN', 'JEFE', 'LABORATORIO', 'AUDITOR', 'DUEÑO'];
  static const List<String> cargosOperativos = ['TÉCNICO', 'BIÓLOGO', 'QFB', 'JEFE DE LABORATORIO', 'ADMINISTRADOR'];

  static const Map<String, String> rolToOperativoDefault = {
    'ADMIN': 'ADMINISTRADOR',
    'JEFE': 'JEFE DE LABORATORIO',
    'LABORATORIO': 'TÉCNICO',
    'AUDITOR': 'QFB',
    'DUEÑO': 'DIRECTOR GENERAL',
  };

  void recordActivity() {
    _lastActivityMs = DateTime.now().millisecondsSinceEpoch;
    _resetInactivityTimer();
  }

  void _resetInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: inactivityTimeoutMinutes), () {
      if (_isAuthenticated && _currentUser != null) {
        debugPrint('AuthService: Session expired due to inactivity');
        logout();
        notifyListeners();
      }
    });
  }

  void _startSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: sessionTimeoutMinutes), () {
      if (_isAuthenticated && _currentUser != null) {
        debugPrint('AuthService: Session max duration reached');
        logout();
        notifyListeners();
      }
    });
  }

  Future<bool> login(String userId, String pin, String deviceId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final user = await _authRepository.login(userId, pin, deviceId);
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        _isLoading = false;
        _sessionStart = DateTime.now();
        _startSessionTimer();
        _resetInactivityTimer();
        notifyListeners();
        await _persistUserSession(user);
        return true;
      }
    } catch (e) {
      debugPrint('Backend login failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final usersRaw = prefs.getString('users_list');
    if (usersRaw != null) {
      try {
        final List users = jsonDecode(usersRaw);
        for (final u in users) {
          final uid = u['id']?.toString() ?? '';
          if (uid == userId && u['pin']?.toString() == pin) {
            await prefs.setString('jwt_token', 'local-offline-session');
            final cargoOperativo = u['cargo_operativo'] as String? ?? u['rol'] as String? ?? '';
            _currentUser = User(
              id: uid,
              nombre: u['nombre'] as String? ?? 'Usuario',
              rol: _mapRol(u['rol'] as String? ?? 'Laboratorio'),
              cargo: u['cargo'] as String? ?? '',
              cargoOperativo: cargoOperativo,
              area: u['area'] as String? ?? '',
              supervisor: u['supervisor'] as String? ?? '',
              firma: u['firma'] as String? ?? u['nombre'] as String? ?? '',
            );
            _isAuthenticated = true;
            _isLoading = false;
            _sessionStart = DateTime.now();
            _startSessionTimer();
            _resetInactivityTimer();
            notifyListeners();
            await _persistUserSession(_currentUser!);
            return true;
          }
        }
      } catch (_) {}
    }

    const offlinePins = {
      'usr-admin': {'pin': '1234', 'nombre': 'Admin (Offline)', 'rol': 'ADMIN', 'cargo': 'ADMINISTRADOR'},
      'usr-jefe': {'pin': '0000', 'nombre': 'Jefe (Offline)', 'rol': 'JEFE', 'cargo': 'JEFE DE LABORATORIO'},
      'usr-t1': {'pin': '1111', 'nombre': 'Tecnico (Offline)', 'rol': 'LABORATORIO', 'cargo': 'TÉCNICO'},
      'usr-auditor': {'pin': '2222', 'nombre': 'Auditor (Offline)', 'rol': 'AUDITOR', 'cargo': 'QFB'},
      'usr-dueno': {'pin': '3333', 'nombre': 'Director General (Offline)', 'rol': 'DUEÑO', 'cargo': 'DIRECTOR GENERAL'},
    };
    final offlineUser = offlinePins[userId];
    if (offlineUser != null && pin == offlineUser['pin']) {
      await prefs.setString('jwt_token', 'local-offline-session');
      _currentUser = User(
        id: userId,
        nombre: offlineUser['nombre']!,
        rol: offlineUser['rol']!,
        cargoOperativo: offlineUser['cargo']!,
      );
      _isAuthenticated = true;
      _isLoading = false;
      _sessionStart = DateTime.now();
      _startSessionTimer();
      _resetInactivityTimer();
      notifyListeners();
      await _persistUserSession(_currentUser!);
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _persistUserSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('session_nombre', user.nombre);
    await prefs.setString('session_rol', user.rol);
    await prefs.setString('session_cargo', user.cargo);
    await prefs.setString('session_cargo_operativo', user.cargoOperativo);
    await prefs.setString('session_area', user.area);
    await prefs.setString('session_supervisor', user.supervisor);
    await prefs.setString('session_firma', user.firma);
    await prefs.setString('session_start', _sessionStart?.toIso8601String() ?? '');
  }

  Future<void> logout() async {
    _sessionTimer?.cancel();
    _inactivityTimer?.cancel();
    await _authRepository.logout();
    _currentUser = null;
    _isAuthenticated = false;
    _sessionStart = null;
    notifyListeners();
  }
}
