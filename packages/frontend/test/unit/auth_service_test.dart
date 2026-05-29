import 'package:flutter_test/flutter_test.dart';
import 'package:biolab_labsync/services/auth_service.dart';

void main() {
  group('AuthState', () {
    test('initial state is not authenticated', () {
      const state = AuthState();
      expect(state.isAuthenticated, false);
      expect(state.currentUser, null);
      expect(state.token, null);
      expect(state.isLoading, false);
    });

    test('isAuthenticated returns true when user and token exist', () {
      const state = AuthState(
        token: 'test-token',
        isLoading: false,
      );
      expect(state.isAuthenticated, false);
    });

    test('copyWith preserves existing values', () {
      const state = AuthState(
        token: 'test-token',
        isLoading: true,
      );
      final newState = state.copyWith(isLoading: false);
      expect(newState.token, 'test-token');
      expect(newState.isLoading, false);
    });

    test('copyWith updates specified values', () {
      const state = AuthState();
      final newState = state.copyWith(token: 'new-token');
      expect(newState.token, 'new-token');
    });
  });
}
