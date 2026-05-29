import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final _secureStorage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'auth_token');
  }

  Future<String?> getUserId() async {
    return await _secureStorage.read(key: 'user_id');
  }

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('server_url') ?? 'http://localhost:8000';
  }

  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('device_id') ?? 'dev-unknown';
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'auth_token', value: token);
  }

  Future<void> saveUserId(String userId) async {
    await _secureStorage.write(key: 'user_id', value: userId);
  }

  Future<void> clearAll() async {
    await _secureStorage.delete(key: 'auth_token');
    await _secureStorage.delete(key: 'user_id');
  }
}

final storageService = StorageService();
