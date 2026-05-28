import 'package:flutter_riverpod/flutter_riverpod.dart';

class BackupService {
  Future<String?> createBackup() async {
    return null;
  }

  Future<bool> restoreFromFile(String path) async {
    return false;
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
