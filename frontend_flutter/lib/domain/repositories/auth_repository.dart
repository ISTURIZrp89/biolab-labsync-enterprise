import '../entities/user.dart';

abstract class AuthRepository {
  Future<User?> login(String userId, String pin, String deviceId);
  Future<void> registerDevice(String deviceId, String deviceName, String os);
  Future<String?> getToken();
  Future<void> saveToken(String token);
  Future<void> logout();
}
