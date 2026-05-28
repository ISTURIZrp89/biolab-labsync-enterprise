import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  final GlobalKey<ScaffoldMessengerState> key = GlobalKey<ScaffoldMessengerState>();

  void success(String title, {String? message, BuildContext? context}) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text('$title${message != null ? ': $message' : ''}'),
      backgroundColor: Colors.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  void warning(String title, {String? message, BuildContext? context}) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text('$title${message != null ? ': $message' : ''}'),
      backgroundColor: Colors.orange,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
    ));
  }

  void error(String title, {String? message, BuildContext? context}) {
    final messenger = _getMessenger(context);
    if (messenger == null) return;
    messenger.showSnackBar(SnackBar(
      content: Text('$title${message != null ? ': $message' : ''}'),
      backgroundColor: Colors.red,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 5),
    ));
  }

  ScaffoldMessengerState? _getMessenger(BuildContext? context) {
    if (context != null && context.mounted) {
      return ScaffoldMessenger.of(context);
    }
    final messenger = key.currentState;
    if (messenger != null) return messenger;
    return null;
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});