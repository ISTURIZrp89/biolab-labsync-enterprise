import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/user.dart';

final authProvider = ChangeNotifierProvider<AuthService>((ref) => AuthService());

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null && _token != null;

  Future<bool> login(String userId, String pin) async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$serverUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'pin': pin}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _currentUser = User.fromJson(data['user']);
        await prefs.setString('auth_token', _token!);
        await prefs.setString('user_id', _currentUser!.id.toString());
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUserId = prefs.getString('user_id');
    if (savedToken != null && savedUserId != null) {
      _token = savedToken;
      _isLoading = true;
      notifyListeners();
      try {
        final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
        final response = await http.get(
          Uri.parse('$serverUrl/auth/me'),
          headers: {'Authorization': 'Bearer $savedToken'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          _currentUser = User.fromJson(data['user']);
          _isLoading = false;
          notifyListeners();
          return true;
        }
      } catch (_) {}
      _token = null;
      await prefs.remove('auth_token');
    }
    _isLoading = false;
    notifyListeners();
    return false;
  }
}
