import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/db.dart';

class LicenseService extends ChangeNotifier {
  static const String _apiBase = 'https://api.github.com/repos/ISTURIZrp89/biolab-labsync-license/contents/';
  static const String _licenseUrl = '${_apiBase}license.json';
  static String get _token => String.fromEnvironment('LICENSE_GITHUB_TOKEN');
  static const String _demoKey = 'LABSYNC-DEMO-Y1ZZ-TGJ3';

  static String? _lastFetchError;

  static Future<Map<String, dynamic>?> fetchPrivateFile(String path) async {
    final token = _token;
    _lastFetchError = null;
    if (token.isEmpty) {
      _lastFetchError = 'TOKEN_VACIO';
      return null;
    }
    try {
      final response = await http.get(
        Uri.parse('$_apiBase$path'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/vnd.github.v3+json',
          'Cache-Control': 'no-cache',
        },
      ).timeout(const Duration(seconds: 15));
      _lastFetchError = 'HTTP_${response.statusCode}';
      if (response.statusCode == 200) {
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          if (body['encoding'] == 'base64' && body['content'] != null) {
            final decoded = utf8.decode(base64Decode(body['content']));
            return jsonDecode(decoded) as Map<String, dynamic>;
          }
          _lastFetchError = 'ENCODING_INESPERADO';
          return body;
        } catch (e) {
          _lastFetchError = 'PARSE_ERROR: $e';
          return null;
        }
      }
    } on SocketException catch (e) {
      _lastFetchError = 'RED: $e';
    } on HttpException catch (e) {
      _lastFetchError = 'HTTP: $e';
    } on TimeoutException {
      _lastFetchError = 'TIMEOUT';
    } catch (e) {
      _lastFetchError = 'EXCEPTION: $e';
    }
    return null;
  }

  String? _storedKey;
  String? _deviceId;
  String? _branch;
  bool _activated = false;
  bool _offlineMode = false;
  bool _checking = false;
  String? _lastError;
  bool _decommissioned = false;
  Timer? _periodicTimer;

  String? get storedKey => _storedKey;
  String? get branch => _branch;
  bool get activated => _activated;
  bool get offlineMode => _offlineMode;
  bool get checking => _checking;
  String? get lastError => _lastError;
  bool get decommissioned => _decommissioned;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    _storedKey = prefs.getString('license_key');
    _branch = prefs.getString('license_branch');
    _activated = _storedKey != null && _storedKey!.isNotEmpty;
    if (_activated) {
      await _validateWithGitHub();
    }
    _periodicTimer = Timer.periodic(const Duration(hours: 24), (_) async {
      if (_activated) await _validateWithGitHub();
    });
    notifyListeners();
  }

  Future<bool> activate(String key) async {
    _checking = true;
    _lastError = null;
    notifyListeners();

    if (_token.isEmpty && key == _demoKey) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('license_key', key);
      await prefs.setString('license_branch', 'demo');
      _storedKey = key;
      _branch = 'demo';
      _activated = true;
      _offlineMode = true;
      _checking = false;
      notifyListeners();
      return true;
    }

    try {
      final licenseData = await _fetchLicenseJson();
      if (licenseData == null) {
        _lastError = 'Error de licencia (${_lastFetchError ?? "desconocido"}). Verifica conexion a internet.';
        _checking = false;
        notifyListeners();
        return false;
      }

      final branch = _extractBranch(key);
      final branches = licenseData['branches'] as Map<String, dynamic>? ?? {};
      final validHash = branches[branch] as String?;

      if (validHash == null) {
        _lastError = 'Sucursal no reconocida. Verifica que la clave corresponda a una sucursal valida.';
        _checking = false;
        notifyListeners();
        return false;
      }

      final computedHash = sha256.convert(utf8.encode(key)).toString();
      if (computedHash != validHash) {
        _lastError = 'La clave de activacion no es valida para esta sucursal.';
        _checking = false;
        notifyListeners();
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('license_key', key);
      await prefs.setString('license_branch', branch);
      _storedKey = key;
      _branch = branch;
      _activated = true;
      _offlineMode = false;
      _decommissioned = false;
      _checking = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastError = 'Error al verificar licencia: $e';
      _checking = false;
      notifyListeners();
      return false;
    }
  }

  String _extractBranch(String key) {
    final parts = key.split('-');
    return parts.length >= 2 ? parts[1].toLowerCase() : 'matriz';
  }

  Future<void> _validateWithGitHub() async {
    if (_storedKey == null || _storedKey!.isEmpty) return;
    if (_token.isEmpty && _storedKey == _demoKey) {
      _offlineMode = true;
      notifyListeners();
      return;
    }
    try {
      final licenseData = await _fetchLicenseJson();
      if (licenseData == null) {
        _offlineMode = true;
        notifyListeners();
        return;
      }

      final branches = licenseData['branches'] as Map<String, dynamic>? ?? {};
      final commands = licenseData['device_commands'] as Map<String, dynamic>? ?? {};

      if (_branch == null || !branches.containsKey(_branch)) {
        _activated = false;
        _storedKey = null;
        _lastError = 'La sucursal ya no esta registrada. Contacta al administrador.';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('license_key');
        await prefs.remove('license_branch');
        notifyListeners();
        return;
      }

      final validHash = branches[_branch] as String;
      final computedHash = sha256.convert(utf8.encode(_storedKey!)).toString();
      if (computedHash != validHash) {
        _activated = false;
        _storedKey = null;
        _branch = null;
        _lastError = 'La clave de licencia ha cambiado. Contacta al administrador.';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('license_key');
        await prefs.remove('license_branch');
        notifyListeners();
        return;
      }

      if (_deviceId != null && commands.containsKey(_deviceId)) {
        final cmd = commands[_deviceId] as Map<String, dynamic>? ?? {};
        final action = cmd['action'] as String? ?? '';
        if (action == 'decommission' || action == 'wipe') {
          _decommissioned = true;
          notifyListeners();
          _executeWipe();
          return;
        }
        if (action == 'revoke') {
          _activated = false;
          _storedKey = null;
          _lastError = 'Este equipo ha sido desactivado por el administrador.';
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('license_key');
          await prefs.remove('license_branch');
          notifyListeners();
          return;
        }
      }

      _offlineMode = false;
      notifyListeners();
    } catch (_) {
      _offlineMode = true;
      notifyListeners();
    }
  }

  Future<void> _executeWipe() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final drivePath = prefs.getString('drive_backup_path') ?? '';

      if (drivePath.isNotEmpty) {
        try {
          final db = await LocalDatabase.instance.database;
          final dbPath = db.path;
          final backupDir = Directory(p.join(drivePath, 'backups', _branch ?? 'unknown', _deviceId ?? 'unknown'));
          if (!await backupDir.exists()) await backupDir.create(recursive: true);
          final backupFile = p.join(backupDir.path, 'backup_${DateTime.now().millisecondsSinceEpoch}.db');
          await db.close();
          await File(dbPath).copy(backupFile);
          debugPrint('Database backed up to: $backupFile');
        } catch (e) {
          debugPrint('Backup failed: $e');
        }
      }

      try {
        final dbPath = LocalDatabase.instance.currentDbPath;
        await LocalDatabase.instance.close();
        if (dbPath != null) {
          final dbFile = File(dbPath);
          if (await dbFile.exists()) await dbFile.delete();
          final walFile = File('${dbPath}-wal');
          if (await walFile.exists()) await walFile.delete();
          final shmFile = File('${dbPath}-shm');
          if (await shmFile.exists()) await shmFile.delete();
        }
      } catch (e) {
        debugPrint('DB reset failed: $e');
      }

      await prefs.clear();
      await prefs.setString('device_id', _deviceId ?? '');

      _activated = false;
      _storedKey = null;
      _branch = null;
      _decommissioned = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Wipe error: $e');
    }
  }

  Future<Map<String, dynamic>?> _fetchLicenseJson() async => fetchPrivateFile('license.json');

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
