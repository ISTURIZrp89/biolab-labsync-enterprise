import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UpdateService {
  Timer? _timer;

  void startPeriodicCheck({Duration interval = const Duration(hours: 1)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => checkForUpdates());
  }

  Future<void> checkForUpdates() async {
    // Check version.json from server
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});
