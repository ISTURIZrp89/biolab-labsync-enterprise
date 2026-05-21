import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import 'api_client.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;

  AuthRepositoryImpl({String backendUrl = "http://localhost:8000"})
      : _api = ApiClient(baseUrl: backendUrl);

  @override
  Future<User?> login(String userId, String pin, String deviceId) async {
    try {
      final response = await _api.post(
        '/api/auth/login',
        body: {
          'user_id': userId,
          'pin': pin,
          'device_id': deviceId,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['access_token']);
        await SharedPreferences.getInstance().then((prefs) {
          prefs.setString('jwt_username', data['user_id']);
          prefs.setString('jwt_rol', data['rol']);
        });
        return User(
          id: data['user_id'],
          nombre: data['nombre'],
          rol: data['rol'],
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> registerDevice(String deviceId, String deviceName, String os) async {
    try {
      await _api.post(
        '/api/auth/register-device',
        body: {
          'device_id': deviceId,
          'device_name': deviceName,
          'os': os,
        },
      );
    } catch (_) {}
  }

  @override
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  @override
  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('jwt_username');
    await prefs.remove('jwt_rol');
  }
}
