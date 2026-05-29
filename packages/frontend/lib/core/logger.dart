import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String _name;

  AppLogger(this._name);

  void debug(String message, [Object? error]) {
    if (kDebugMode) {
      print('[DEBUG] $_name: $message${error != null ? ' - $error' : ''}');
    }
  }

  void info(String message) {
    if (kDebugMode) {
      print('[INFO] $_name: $message');
    }
  }

  void warning(String message, [Object? error]) {
    print('[WARNING] $_name: $message${error != null ? ' - $error' : ''}');
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    print('[ERROR] $_name: $message${error != null ? ' - $error' : ''}');
    if (stackTrace != null && kDebugMode) {
      print(stackTrace);
    }
  }
}

AppLogger getLogger(String name) => AppLogger(name);
