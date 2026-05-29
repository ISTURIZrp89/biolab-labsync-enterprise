import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/database/app_database.dart';

class BackupService {
  Future<String?> createBackup() async {
    try {
      final db = AppDatabase();
      final path = await db.exportToDirectory(
        await _getBackupBasePath(),
        label: 'backup',
      );
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<String?> exportBackup(String path) async {
    try {
      final db = AppDatabase();
      final exportedPath = await db.exportToDirectory(path);
      return exportedPath;
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> restoreFromFile(String path) async {
    return false;
  }

  Future<String> _getBackupBasePath() async {
    return '.';
  }
}

final backupServiceProvider = Provider<BackupService>((ref) {
  return BackupService();
});
