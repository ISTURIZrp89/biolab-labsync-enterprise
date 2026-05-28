import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  void success(String title, {String? message}) {
    debugPrint('SUCCESS: $title - ${message ?? ""}');
  }

  void warning(String title, {String? message}) {
    debugPrint('WARNING: $title - ${message ?? ""}');
  }

  void error(String title, {String? message}) {
    debugPrint('ERROR: $title - ${message ?? ""}');
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
