import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/auth_service.dart';

class PermissionService {
  static const Map<String, List<String>> rolePermissions = {
    'ADMIN': ['read', 'write', 'delete', 'admin', 'audit', 'manage_users', 'closure'],
    'JEFE': ['read', 'write', 'audit', 'closure'],
    'LABORATORIO': ['read', 'write'],
    'AUDITOR': ['read', 'audit'],
    'DUENO': ['read', 'write', 'delete', 'admin', 'audit', 'closure'],
  };

  bool hasPermission(String role, String permission) {
    return rolePermissions[role]?.contains(permission) ?? false;
  }

  List<String> getPermissions(String role) {
    return rolePermissions[role] ?? [];
  }

  bool canManageUsers(String role) => hasPermission(role, 'manage_users');
  bool canAccessAudit(String role) => hasPermission(role, 'audit');
  bool canCloseDay(String role) => hasPermission(role, 'closure');
  bool canDelete(String role) => hasPermission(role, 'delete');
}

final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

final currentUserRoleProvider = Provider<String>((ref) {
  final authState = ref.watch(authProvider);
  return authState.currentUser?.rol ?? '';
});

final hasPermissionProvider = Provider.family<bool, String>((ref, permission) {
  final role = ref.watch(currentUserRoleProvider);
  final service = ref.watch(permissionServiceProvider);
  return service.hasPermission(role, permission);
});
