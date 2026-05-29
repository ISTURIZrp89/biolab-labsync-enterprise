import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logger.dart';
import '../domain/entities/user.dart';

final _log = getLogger('AuthService');

class AuthState {
  final User? currentUser;
  final String? token;
  final bool isLoading;

  const AuthState({this.currentUser, this.token, this.isLoading = false});

  bool get isAuthenticated => currentUser != null && token != null;

  AuthState copyWith({User? currentUser, String? token, bool? isLoading}) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      token: token ?? this.token,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthService extends Notifier<AuthState> {
  final _secureStorage = const FlutterSecureStorage();

  @override
  AuthState build() => const AuthState();

  Future<bool> login(String userId, String pin, String deviceId) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$serverUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'pin': pin, 'device_id': deviceId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['access_token'] as String;
        final user = User.fromJson({
          'id': data['user_id'],
          'nombre': data['nombre'],
          'rol': data['rol'],
        });
        await _secureStorage.write(key: 'auth_token', value: token);
        await _secureStorage.write(key: 'user_id', value: user.id.toString());
        await prefs.setString('user_id', user.id.toString());
        state = AuthState(currentUser: user, token: token, isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e, st) {
      _log.error('Login failed', e, st);
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_id');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    state = const AuthState();
  }

  Future<bool> tryAutoLogin() async {
    final savedToken = await _secureStorage.read(key: 'auth_token');
    final savedUserId = await _secureStorage.read(key: 'user_id');
    if (savedToken != null && savedUserId != null) {
      state = AuthState(token: savedToken, isLoading: true);
      try {
        final prefs = await SharedPreferences.getInstance();
        final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
        final response = await http.get(
          Uri.parse('$serverUrl/api/auth/me'),
          headers: {'Authorization': 'Bearer $savedToken'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = User.fromJson(data['user']);
          state = AuthState(currentUser: user, token: savedToken, isLoading: false);
          return true;
        }
      } catch (_) {}
      await _secureStorage.delete(key: 'auth_token');
    }
    state = const AuthState();
    return false;
  }

  Future<void> cachePinForOffline(String userId, String pin) async {
    final existing = await _secureStorage.read(key: 'offline_pins');
    final pins = existing != null
        ? Map<String, dynamic>.from(jsonDecode(existing) as Map)
        : <String, dynamic>{};
    pins[userId] = pin;
    await _secureStorage.write(key: 'offline_pins', value: jsonEncode(pins));
  }

  Future<bool> tryOfflineLogin(String userId, String pin) async {
    final cached = await _secureStorage.read(key: 'offline_pins');
    if (cached == null) return false;
    try {
      final pins = jsonDecode(cached) as Map<String, dynamic>;
      return pins[userId] == pin;
    } catch (_) {
      return false;
    }
  }
}

final authProvider = NotifierProvider<AuthService, AuthState>(AuthService.new);
