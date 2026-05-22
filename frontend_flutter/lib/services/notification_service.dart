import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

enum NotificationType { info, success, warning, error }

class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  bool dismissed;

  AppNotification({
    required this.id,
    required this.title,
    this.message = '',
    this.type = NotificationType.info,
    DateTime? timestamp,
    this.dismissed = false,
  }) : timestamp = timestamp ?? DateTime.now();

  Color get color {
    switch (type) {
      case NotificationType.success: return Colors.green;
      case NotificationType.warning: return Colors.orange;
      case NotificationType.error: return Colors.red;
      case NotificationType.info: return Colors.blue;
    }
  }

  IconData get icon {
    switch (type) {
      case NotificationType.success: return Icons.check_circle;
      case NotificationType.warning: return Icons.warning;
      case NotificationType.error: return Icons.error;
      case NotificationType.info: return Icons.info;
    }
  }
}

class NotificationService extends ChangeNotifier {
  final List<AppNotification> _notifications = [];
  final int _maxNotifications = 50;
  Timer? _cleanupTimer;
  bool _disposed = false;

  List<AppNotification> get notifications => List.unmodifiable(_notifications.where((n) => !n.dismissed));
  int get unreadCount => _notifications.where((n) => !n.dismissed).length;

  NotificationService() {
    _cleanupTimer = Timer.periodic(const Duration(minutes: 5), (_) => _cleanup());
  }

  void add(AppNotification notification) {
    _notifications.insert(0, notification);
    if (_notifications.length > _maxNotifications) {
      _notifications.removeLast();
    }
    _safeNotify();
  }

  void success(String title, {String message = ''}) {
    add(AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: NotificationType.success,
    ));
  }

  void warning(String title, {String message = ''}) {
    add(AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: NotificationType.warning,
    ));
  }

  void error(String title, {String message = ''}) {
    add(AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: NotificationType.error,
    ));
  }

  void info(String title, {String message = ''}) {
    add(AppNotification(
      id: 'n-${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      message: message,
      type: NotificationType.info,
    ));
  }

  void dismiss(String id) {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx >= 0) {
      _notifications[idx].dismissed = true;
      _safeNotify();
    }
  }

  void dismissAll() {
    for (var n in _notifications) {
      n.dismissed = true;
    }
    _safeNotify();
  }

  void _cleanup() {
    final before = _notifications.length;
    _notifications.removeWhere((n) => n.dismissed && DateTime.now().difference(n.timestamp).inHours > 24);
    if (_notifications.length != before) _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cleanupTimer?.cancel();
    super.dispose();
  }
}
