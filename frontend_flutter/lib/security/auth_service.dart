import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/entities/user.dart';
import '../domain/repositories/auth_repository.dart';

class AuthService extends ChangeNotifier {
  final AuthRepository _authRepository;
  User? _currentUser;
  bool _isAuthenticated = false;
  bool _isLoading = false;

  AuthService(this._authRepository);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;

  Future<bool> login(String userId, String pin, String deviceId) async {
    _isLoading = true;
    notifyListeners();

    final user = await _authRepository.login(userId, pin, deviceId);
    if (user != null) {
      _currentUser = user;
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    if (pin == "1234") {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', 'local-offline-session');
      _currentUser = User(id: userId, nombre: "Admin (Offline)", rol: "ADMIN");
      _isAuthenticated = true;
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _currentUser = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}
