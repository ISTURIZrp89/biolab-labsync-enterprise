import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AuditService {
  Future<void> init() async {}

  Future<void> log({
    required String action,
    String type = 'info',
    String? userId,
    String? userName,
    String? details,
    String? deviceId,
    String? entityId,
    List<Map<String, dynamic>> changedFields = const [],
  }) async {
    debugPrint('AUDIT: $action - $userId - $details');
  }
}

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService();
});
