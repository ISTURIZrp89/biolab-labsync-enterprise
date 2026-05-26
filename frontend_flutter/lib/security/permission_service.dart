import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/form_definitions.dart';
import 'auth_service.dart';

class PermissionService extends ChangeNotifier {
  Set<String> _allowedModules = {};
  Map<String, String> _modulePermissions = {};
  bool _permLoaded = false;

  static const Map<String, Set<String>> defaultRolModules = {
    'ADMIN': {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'config', 'users', 'closures', 'reports', 'muestras'},
    'JEFE': {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'closures', 'reports'},
    'LABORATORIO': {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora'},
    'AUDITOR': {'reports'},
    'DUEÑO': {'incubadoras', 'autoclaves', 'ultracongeladores', 'equipos', 'procesamiento', 'bitacora', 'config', 'reports', 'muestras'},
  };

  static const Map<String, String> defaultRolModulePerms = {
    'ADMIN': 'owner',
    'JEFE': 'edit',
    'LABORATORIO': 'edit',
    'AUDITOR': 'view',
    'DUEÑO': 'owner',
  };

  Set<String> get allowedModules => _allowedModules;
  bool get permLoaded => _permLoaded;

  Future<void> loadPermissions(AuthService auth) async {
    final user = auth.currentUser;
    if (user == null) {
      _allowedModules = {};
      _permLoaded = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('users_list');
    bool found = false;

    if (raw != null) {
      final list = _tryDecodeList(raw);
      for (final u in list) {
        if (u['pin'] == user.id || u['id'] == user.id) {
          final p = (u as Map)['permisos'] as String? ?? '';
          final permLevel = (u as Map)['permiso_nivel'] as String? ?? '';
          if (p == 'todos' || p.isEmpty) {
            _allowedModules = Set.from(defaultRolModules[user.rol] ?? defaultRolModules['LABORATORIO']!);
          } else {
            _allowedModules = p.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet();
          }
          if (permLevel.isNotEmpty) {
            for (final mod in _allowedModules) {
              _modulePermissions[mod] = permLevel;
            }
          }
          found = true;
          break;
        }
      }
    }

    if (!found) {
      _allowedModules = Set.from(defaultRolModules[user.rol] ?? defaultRolModules['LABORATORIO']!);
    }

    for (final mod in _allowedModules) {
      _modulePermissions.putIfAbsent(mod, () => defaultRolModulePerms[user.rol] ?? 'view');
    }

    _permLoaded = true;
    notifyListeners();
  }

  bool canAccess(String module) => _allowedModules.contains(module);

  bool canEdit(String module) {
    final perm = _modulePermissions[module];
    return perm == 'edit' || perm == 'owner';
  }

  bool isOwner(String module) {
    return _modulePermissions[module] == 'owner';
  }

  bool canAccessAny() => _allowedModules.isNotEmpty;

  List<FormModuleDef> getAccessibleModules() {
    return formModules.where((m) => _allowedModules.contains(m['module'])).toList();
  }

  List<FormModuleDef> getEditableModules() {
    return formModules.where((m) => canEdit(m['module'])).toList();
  }

  void savePermissionsForUser(String userId, Set<String> modules, {String? permLevel}) {
    // Permissions are persisted in users_list in SharedPreferences
    // This is handled at the settings screen level
  }

  List<dynamic> _tryDecodeList(dynamic raw) {
    try {
      if (raw is String) return (jsonDecode(raw) as List<dynamic>);
      if (raw is List) return raw;
    } catch (_) {}
    return [];
  }
}
