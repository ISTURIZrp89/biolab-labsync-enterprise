import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EditLock {
  final String entryId;
  final String userId;
  final String userName;
  final String module;
  final DateTime lockedAt;
  final String lockToken;

  EditLock({
    required this.entryId,
    required this.userId,
    required this.userName,
    required this.module,
    required this.lockedAt,
    required this.lockToken,
  });

  bool get isExpired => DateTime.now().difference(lockedAt).inMinutes > 15;

  Map<String, dynamic> toJson() => {
    'entryId': entryId,
    'userId': userId,
    'userName': userName,
    'module': module,
    'lockedAt': lockedAt.toIso8601String(),
    'lockToken': lockToken,
  };

  factory EditLock.fromJson(Map<String, dynamic> json) => EditLock(
    entryId: json['entryId'] as String,
    userId: json['userId'] as String,
    userName: json['userName'] as String? ?? '',
    module: json['module'] as String? ?? '',
    lockedAt: DateTime.parse(json['lockedAt'] as String),
    lockToken: json['lockToken'] as String,
  );
}

class EditLockService extends ChangeNotifier {
  final Map<String, EditLock> _locks = {};
  Timer? _cleanupTimer;

  EditLockService() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 2), (_) => _cleanupExpired());
    _loadLocks();
  }

  bool isLocked(String entryId) {
    final lock = _locks[entryId];
    if (lock == null) return false;
    if (lock.isExpired) {
      _locks.remove(entryId);
      _saveLocks();
      return false;
    }
    return true;
  }

  bool canEdit(String entryId, String userId) {
    final lock = _locks[entryId];
    if (lock == null) return true;
    if (lock.isExpired) {
      _locks.remove(entryId);
      _saveLocks();
      return true;
    }
    return lock.userId == userId;
  }

  String? getLockHolder(String entryId) {
    final lock = _locks[entryId];
    if (lock == null || lock.isExpired) return null;
    return lock.userName;
  }

  EditLock? getLock(String entryId) {
    final lock = _locks[entryId];
    if (lock == null || lock.isExpired) return null;
    return lock;
  }

  Future<String?> acquireLock(String entryId, String userId, String userName, String module) async {
    if (_locks.containsKey(entryId)) {
      final existing = _locks[entryId]!;
      if (!existing.isExpired && existing.userId != userId) {
        return null;
      }
    }
    final token = _generateToken();
    _locks[entryId] = EditLock(
      entryId: entryId,
      userId: userId,
      userName: userName,
      module: module,
      lockedAt: DateTime.now(),
      lockToken: token,
    );
    _saveLocks();
    notifyListeners();
    return token;
  }

  void releaseLock(String entryId, String lockToken) {
    final lock = _locks[entryId];
    if (lock != null && lock.lockToken == lockToken) {
      _locks.remove(entryId);
      _saveLocks();
      notifyListeners();
    }
  }

  void releaseAllForUser(String userId) {
    _locks.removeWhere((_, lock) => lock.userId == userId);
    _saveLocks();
    notifyListeners();
  }

  void _cleanupExpired() {
    bool changed = false;
    _locks.removeWhere((_, lock) {
      if (lock.isExpired) { changed = true; return true; }
      return false;
    });
    if (changed) {
      _saveLocks();
      notifyListeners();
    }
  }

  String _generateToken() {
    final r = DateTime.now().millisecondsSinceEpoch;
    return 'lock-$r-${r.toString().hashCode}';
  }

  Future<void> _saveLocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _locks.map((k, v) => MapEntry(k, v.toJson()));
      await prefs.setString('edit_locks', jsonEncode(data));
    } catch (_) {}
  }

  Future<void> _loadLocks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('edit_locks');
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _locks.clear();
        data.forEach((k, v) {
          _locks[k] = EditLock.fromJson(v as Map<String, dynamic>);
        });
        _cleanupExpired();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
