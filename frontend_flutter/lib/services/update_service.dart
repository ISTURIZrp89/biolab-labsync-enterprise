import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService extends ChangeNotifier {
  final String backendUrl;
  Timer? _checkTimer;

  bool _hasUpdate = false;
  String _latestVersion = '';
  String _currentVersion = '7.1.0';
  String _releaseNotes = '';
  bool _isMandatory = false;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  Map<String, dynamic>? _downloadInfo;
  bool _autoInstall = true;

  bool get hasUpdate => _hasUpdate;
  String get latestVersion => _latestVersion;
  String get currentVersion => _currentVersion;
  String get releaseNotes => _releaseNotes;
  bool get isMandatory => _isMandatory;
  bool get isChecking => _isChecking;
  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String get statusMessage => _statusMessage;
  Map<String, dynamic>? get downloadInfo => _downloadInfo;
  bool get autoInstall => _autoInstall;

  UpdateService({this.backendUrl = "http://localhost:8000"});

  void startPeriodicCheck({Duration interval = const Duration(minutes: 30)}) {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(interval, (_) => checkForUpdates());
  }

  void stopPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = null;
  }

  Future<void> checkForUpdates() async {
    if (_isChecking || _isDownloading) return;

    _isChecking = true;
    _statusMessage = 'Verificando actualizaciones...';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final platform = kIsWeb ? 'web' : 'desktop';

      final response = await http.get(
        Uri.parse('$backendUrl/api/updates/check?current_version=$_currentVersion&platform=$platform'),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        _hasUpdate = data['has_update'] == true;
        _latestVersion = data['latest_version'] ?? _currentVersion;
        _releaseNotes = data['release_notes'] ?? '';
        _isMandatory = data['mandatory'] ?? false;
        _downloadInfo = data['download'];
        _autoInstall = prefs.getBool('auto_install') ?? true;

        await prefs.setString('latest_version', _latestVersion);
        await prefs.setBool('has_update', _hasUpdate);

        if (_hasUpdate) {
          _statusMessage = 'Nueva version disponible: v$_latestVersion';
          notifyListeners();
        } else {
          _statusMessage = 'La aplicacion esta actualizada';
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('Update check error: $e');
      _statusMessage = 'Error al verificar actualizaciones';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> setAutoInstall(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_install', value);
    _autoInstall = value;
    notifyListeners();
  }

  Future<void> installNow() async {
    _statusMessage = 'Actualizacion disponible. Descarga desde el servidor.';
    notifyListeners();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}
