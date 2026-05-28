import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../data/repositories/auth_repository.dart';

part 'auth_service.g.dart';

class AuthService {
  final AuthRepository _repo;

  AuthService(this._repo);

  Future<bool> login(String email, String password) async {
    final result = await _repo.login(email, password);
    return result['success'] == true;
  }
}

@riverpod
AuthService authService(AuthServiceRef ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthService(repo);
}
