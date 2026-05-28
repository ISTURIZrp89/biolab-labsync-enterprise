import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final http.Client _client;
  final String _baseUrl;

  AuthRepository(this._client, this._baseUrl);

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/auth/login'),
      body: {'email': email, 'password': password},
    );
    if (response.statusCode == 200) {
      return {'success': true};
    }
    return {'success': false, 'error': 'Credenciales inválidas'};
  }
}

@riverpod
AuthRepository authRepository(AuthRepositoryRef ref) {
  return AuthRepository(http.Client(), 'http://localhost:8000');
}
