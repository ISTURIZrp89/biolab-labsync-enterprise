import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LicenseService extends ChangeNotifier {
  static const String _licenseUrl = 'https://raw.githubusercontent.com/ISTURIZrp89/biolab-labsync/master/license.json';

  String? _storedKey;
  String? _deviceId;
  bool _activated = false;
  bool _offlineMode = false;
  bool _checking = false;
  String? _lastError;
  List<String> _networkDevices = [];
  Timer? _periodicTimer;

  String? get storedKey => _storedKey;
  bool get activated => _activated;
  bool get offlineMode => _offlineMode;
  bool get checking => _checking;
  String? get lastError => _lastError;
  List<String> get networkDevices => List.unmodifiable(_networkDevices);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('device_id');
    _storedKey = prefs.getString('license_key');
    _activated = _storedKey != null && _storedKey!.isNotEmpty;
    if (_activated) {
      await _validateWithGitHub();
    }
    _periodicTimer = Timer.periodic(const Duration(minutes: 10), (_) async {
      if (_activated) await _validateWithGitHub();
    });
    notifyListeners();
  }

  Future<bool> activate(String key) async {
    _checking = true;
    _lastError = null;
    notifyListeners();

    try {
      final valid = await _checkKeyAgainstGitHub(key);
      if (valid) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('license_key', key);
        _storedKey = key;
        _activated = true;
        _offlineMode = false;
        _checking = false;
        notifyListeners();
        return true;
      } else {
        _lastError = 'La clave de activacion no es valida o ha sido revocada';
        _checking = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _lastError = 'Error al verificar licencia: $e';
      _checking = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> _validateWithGitHub() async {
    try {
      final licenseData = await _fetchLicenseJson();
      if (licenseData == null) {
        _offlineMode = true;
        notifyListeners();
        return;
      }

      final storedHash = licenseData['current_key_hash'] as String? ?? '';
      final revoked = (licenseData['revoked_device_ids'] as List?)?.cast<String>() ?? [];

      if (_storedKey == null || _storedKey!.isEmpty) {
        _activated = false;
        _offlineMode = false;
        notifyListeners();
        return;
      }

      final computedHash = sha256.convert(utf8.encode(_storedKey!)).toString();
      if (computedHash != storedHash) {
        _activated = false;
        _storedKey = null;
        _lastError = 'La clave de licencia ha cambiado. Contacta al administrador.';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('license_key');
        notifyListeners();
        return;
      }

      if (_deviceId != null && revoked.contains(_deviceId)) {
        _activated = false;
        _storedKey = null;
        _lastError = 'Este equipo ha sido desactivado. Contacta al administrador.';
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('license_key');
        notifyListeners();
        return;
      }

      _offlineMode = false;
      notifyListeners();
    } catch (_) {
      _offlineMode = true;
      notifyListeners();
    }
  }

  Future<bool> _checkKeyAgainstGitHub(String key) async {
    try {
      final licenseData = await _fetchLicenseJson();
      if (licenseData == null) return false;

      final storedHash = licenseData['current_key_hash'] as String? ?? '';
      final computedHash = sha256.convert(utf8.encode(key)).toString();

      return computedHash == storedHash;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _fetchLicenseJson() async {
    try {
      final response = await http.get(
        Uri.parse(_licenseUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }
}
