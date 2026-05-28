class PermissionService {
  static const Map<String, List<String>> rolePermissions = {
    'ADMIN': ['read', 'write', 'delete', 'admin', 'audit'],
    'JEFE': ['read', 'write', 'audit'],
    'LABORATORIO': ['read', 'write'],
    'AUDITOR': ['read', 'audit'],
    'DUENO': ['read', 'write', 'delete', 'admin', 'audit'],
  };

  bool hasPermission(String role, String permission) {
    return rolePermissions[role]?.contains(permission) ?? false;
  }
}
