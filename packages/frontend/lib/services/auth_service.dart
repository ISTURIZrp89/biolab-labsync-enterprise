import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/user.dart';

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
  @override
  AuthState build() => const AuthState();

  Future<bool> login(String userId, String pin, String deviceId) async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
      final response = await http.post(
        Uri.parse('$serverUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'pin': pin, 'device_id': deviceId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'] as String;
        final user = User.fromJson(data['user']);
        await prefs.setString('auth_token', token);
        await prefs.setString('user_id', user.id.toString());
        state = AuthState(currentUser: user, token: token, isLoading: false);
        return true;
      }
      state = state.copyWith(isLoading: false);
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    state = const AuthState();
  }

  Future<bool> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('auth_token');
    final savedUserId = prefs.getString('user_id');
    if (savedToken != null && savedUserId != null) {
      state = AuthState(token: savedToken, isLoading: true);
      try {
        final serverUrl = prefs.getString('server_url') ?? 'http://localhost:8000';
        final response = await http.get(
          Uri.parse('$serverUrl/auth/me'),
          headers: {'Authorization': 'Bearer $savedToken'},
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = User.fromJson(data['user']);
          state = AuthState(currentUser: user, token: savedToken, isLoading: false);
          return true;
        }
      } catch (_) {}
      await prefs.remove('auth_token');
    }
    state = const AuthState();
    return false;
  }
}

final authProvider = NotifierProvider<AuthService, AuthState>(AuthService.new);