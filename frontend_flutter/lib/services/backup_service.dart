import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';

class BackupInfo {
  final String path;
  final String type;
  final int year;
  final int? month;
  final String? day;
  final DateTime createdAt;

  BackupInfo({
    required this.path, required this.type, required this.year,
    this.month, this.day, required this.createdAt,
  });

  String get label {
    if (type == 'diario' && day != null) return '$day';
    if (type == 'mensual' && month != null) {
      final ms = ['Enero','Febrero','Marzo','Abril','Mayo','Junio',
        'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];
      return '${ms[month! - 1]} $year';
    }
    if (type == 'anual') return '$year';
    return '$year-${month?.toString().padLeft(2, "0") ?? "??"}';
  }
}

class BackupService extends ChangeNotifier {
  final LocalDatabase _db;
  bool _loading = false;
  String? _lastError;

  BackupService({LocalDatabase? localDb}) : _db = localDb ?? LocalDatabase.instance;

  bool get loading => _loading;
  String? get lastError => _lastError;

  static Future<String> _getBackupDir() async {
    final prefs = await SharedPreferences.getInstance();
    final savePath = prefs.getString('save_path') ?? '';
    if (savePath.isEmpty) return '';
    return p.join(savePath, 'backups');
  }

  Future<String?> backupDaily(String date) async {
    _lastError = null;
    try {
      if (!await _db.checkIntegrity()) {
        _lastError = 'Base de datos corrupta. No se puede respaldar.';
        return null;
      }
      final base = await _getBackupDir();
      if (base.isEmpty) return null;
      final parts = date.split('-');
      if (parts.length != 3) return null;
      final year = parts[0];
      final dir = Directory(p.join(base, year, 'diarios'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final outPath = p.join(dir.path, '$date.db');
      await _db.exportToDirectory(dir.path, label: date);
      final file = File(outPath);
      if (!await file.exists()) {
        _lastError = 'Error al crear archivo de respaldo';
        return null;
      }
      if (!await LocalDatabase.verifyBackupIntegrity(outPath)) {
        await file.delete();
        _lastError = 'El respaldo generado esta corrupto';
        return null;
      }
      return outPath;
    } catch (e) {
      _lastError = 'Error en backup diario: $e';
      return null;
    }
  }

  Future<String?> backupMonthly(int year, int month) async {
    _lastError = null;
    try {
      if (!await _db.checkIntegrity()) {
        _lastError = 'Base de datos corrupta. No se puede respaldar.';
        return null;
      }
      final base = await _getBackupDir();
      if (base.isEmpty) return null;
      final dir = Directory(p.join(base, year.toString(), 'mensuales'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final label = '${month.toString().padLeft(2, "0")}-'
          '${["","Enero","Febrero","Marzo","Abril","Mayo","Junio",
              "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"][month]}';
      final outPath = p.join(dir.path, '$label.db');
      if (await File(outPath).exists()) {
        final oldPath = '$outPath.pre_reopen.${DateTime.now().millisecondsSinceEpoch}';
        await File(outPath).copy(oldPath);
      }
      await _db.exportToDirectory(dir.path, label: label);
      final file = File(outPath);
      if (!await file.exists()) {
        _lastError = 'Error al crear backup mensual';
        return null;
      }
      if (!await LocalDatabase.verifyBackupIntegrity(outPath)) {
        await file.delete();
        _lastError = 'El backup mensual generado esta corrupto';
        return null;
      }
      await _cleanupDailyBackups(year, month);
      return outPath;
    } catch (e) {
      _lastError = 'Error en backup mensual: $e';
      return null;
    }
  }

  Future<String?> backupAnnual(int year) async {
    _lastError = null;
    try {
      if (!await _db.checkIntegrity()) {
        _lastError = 'Base de datos corrupta. No se puede respaldar.';
        return null;
      }
      final base = await _getBackupDir();
      if (base.isEmpty) return null;
      final dir = Directory(p.join(base, year.toString(), 'anuales'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final outPath = p.join(dir.path, '$year.db');
      await _db.exportToDirectory(dir.path, label: '$year');
      final file = File(outPath);
      if (!await file.exists()) {
        _lastError = 'Error al crear backup anual';
        return null;
      }
      if (!await LocalDatabase.verifyBackupIntegrity(outPath)) {
        await file.delete();
        _lastError = 'El backup anual generado esta corrupto';
        return null;
      }
      final monthlyDir = Directory(p.join(base, year.toString(), 'mensuales'));
      if (await monthlyDir.exists()) {
        await monthlyDir.delete(recursive: true);
      }
      return outPath;
    } catch (e) {
      _lastError = 'Error en backup anual: $e';
      return null;
    }
  }

  Future<String> backupManual() async {
    final base = await _getBackupDir();
    if (base.isEmpty) throw Exception('Configure la carpeta de respaldos en Ajustes');
    final dir = Directory(p.join(base, 'manuales'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final ts = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
    final outPath = p.join(dir.path, 'manual_$ts.db');
    await _db.exportToDirectory(dir.path, label: 'manual_$ts');
    if (!await LocalDatabase.verifyBackupIntegrity(outPath)) {
      await File(outPath).delete();
      throw Exception('El respaldo manual generado esta corrupto');
    }
    return outPath;
  }

  Future<bool> restoreFrom(String backupPath) async {
    _lastError = null;
    _loading = true;
    notifyListeners();
    try {
      await _db.importFromFile(backupPath);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Error al restaurar: $e';
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> restoreFromFile(String filePath) async {
    return restoreFrom(filePath);
  }

  Future<void> _cleanupDailyBackups(int year, int month) async {
    try {
      final base = await _getBackupDir();
      if (base.isEmpty) return;
      final dailyDir = Directory(p.join(base, year.toString(), 'diarios'));
      if (!await dailyDir.exists()) return;
      final prefix = '$year-${month.toString().padLeft(2, "0")}-';
      await for (final f in dailyDir.list()) {
        if (f is File && p.basename(f.path).startsWith(prefix)) {
          await f.delete();
        }
      }
    } catch (_) {}
  }

  Future<List<BackupInfo>> listBackups() async {
    final result = <BackupInfo>[];
    try {
      final base = await _getBackupDir();
      if (base.isEmpty) return result;
      final baseDir = Directory(base);
      if (!await baseDir.exists()) return result;
      await for (final yearEnt in baseDir.list()) {
        if (yearEnt is! Directory) continue;
        final year = int.tryParse(p.basename(yearEnt.path));
        if (year == null) continue;
        for (final type in ['diarios', 'mensuales', 'anuales']) {
          final typeDir = Directory(p.join(yearEnt.path, type));
          if (!await typeDir.exists()) continue;
          await for (final f in typeDir.list()) {
            if (f is! File || !f.path.endsWith('.db')) continue;
            final name = p.basenameWithoutExtension(f.path);
            final stat = await f.stat();
            if (type == 'diarios') {
              result.add(BackupInfo(
                path: f.path, type: 'diario', year: year,
                day: name, createdAt: stat.modified,
              ));
            } else if (type == 'mensuales') {
              final m = int.tryParse(name.split('-')[0]) ?? 0;
              result.add(BackupInfo(
                path: f.path, type: 'mensual', year: year,
                month: m, createdAt: stat.modified,
              ));
            } else {
              result.add(BackupInfo(
                path: f.path, type: 'anual', year: year,
                createdAt: stat.modified,
              ));
            }
          }
        }
      }
      result.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (_) {}
    return result;
  }
}