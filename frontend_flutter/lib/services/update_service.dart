import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'license_service.dart';

class UpdateService extends ChangeNotifier {
  Timer? _checkTimer;
  Timer? _downloadTimer;

  bool _hasUpdate = false;
  String _latestVersion = '';
  String _currentVersion = '1.0.0';
  String _releaseNotes = '';
  bool _isMandatory = false;
  bool _isChecking = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String _statusMessage = '';
  String? _downloadedPath;
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
  String? get downloadedPath => _downloadedPath;
  bool get autoInstall => _autoInstall;

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
      final data = await LicenseService.fetchPrivateFile('update.json');
      if (data == null) {
        _statusMessage = 'No se pudo verificar actualizaciones';
        _isChecking = false;
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      _latestVersion = data['latest_version'] as String? ?? _currentVersion;
      _releaseNotes = data['release_notes'] as String? ?? '';
      _isMandatory = data['mandatory'] as bool? ?? false;
      _autoInstall = prefs.getBool('auto_install') ?? true;

      final currentParts = _currentVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final latestParts = _latestVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      _hasUpdate = false;
      for (int i = 0; i < 3; i++) {
        final cur = i < currentParts.length ? currentParts[i] : 0;
        final lat = i < latestParts.length ? latestParts[i] : 0;
        if (lat > cur) { _hasUpdate = true; break; }
        if (lat < cur) break;
      }

      if (_hasUpdate) {
        _statusMessage = 'Nueva version disponible: v$_latestVersion';
        await prefs.setString('latest_version', _latestVersion);
        await prefs.setBool('has_update', true);
        notifyListeners();

        if (_autoInstall) {
          await _downloadUpdate(data);
        }
      } else {
        _statusMessage = 'La aplicacion esta actualizada';
        await prefs.setBool('has_update', false);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Update check error: $e');
      _statusMessage = 'Error al verificar actualizaciones';
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  Future<void> _downloadUpdate(Map<String, dynamic> data) async {
    final downloads = data['downloads'] as Map<String, dynamic>? ?? {};
    final checksums = data['checksums'] as Map<String, dynamic>? ?? {};

    String? downloadUrl;
    String? expectedChecksum;
    String platform;

    if (Platform.isWindows) {
      platform = 'windows';
    } else if (Platform.isMacOS) {
      platform = Platform.isIOS ? 'macos_arm' : 'macos_intel';
    } else if (Platform.isLinux) {
      platform = 'linux';
    } else {
      return;
    }

    downloadUrl = downloads[platform] as String?;
    expectedChecksum = checksums[platform] as String?;

    if (downloadUrl == null || downloadUrl.isEmpty) {
      _statusMessage = 'Descarga no disponible para esta plataforma aun';
      notifyListeners();
      return;
    }

    _isDownloading = true;
    _downloadProgress = 0;
    _statusMessage = 'Descargando actualizacion...';
    notifyListeners();

    try {
      final dir = await getTemporaryDirectory();
      final ext = platform == 'windows' ? '.exe' : (platform == 'linux' ? '.AppImage' : '.dmg');
      final filePath = p.join(dir.path, 'biolab_labsync_$latestVersion$ext');
      final file = File(filePath);

      final response = await http.Client().send(
        http.Request('GET', Uri.parse(downloadUrl)),
      );

      if (response.statusCode != 200) {
        _statusMessage = 'Error al descargar actualizacion';
        _isDownloading = false;
        notifyListeners();
        return;
      }

      final sink = file.openWrite();
      final contentLength = response.contentLength ?? 0;
      int received = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (contentLength > 0) {
          _downloadProgress = received / contentLength;
          _statusMessage = 'Descargando... ${(_downloadProgress * 100).toStringAsFixed(0)}%';
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();

      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final actualHash = sha256.convert(bytes).toString();
        if (actualHash != expectedChecksum) {
          await file.delete();
          _statusMessage = 'Error: el archivo descargado esta corrupto';
          _isDownloading = false;
          notifyListeners();
          return;
        }
      }

      _downloadedPath = filePath;
      _downloadProgress = 1.0;
      _statusMessage = 'Actualizacion descargada. Instalando...';
      notifyListeners();

      await _installUpdate(filePath, platform);
    } catch (e) {
      debugPrint('Download error: $e');
      _statusMessage = 'Error al descargar actualizacion';
    } finally {
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _installUpdate(String filePath, String platform) async {
    try {
      if (platform == 'windows') {
        final installer = File(filePath);
        if (await installer.exists()) {
          await Process.start(installer.path, ['/silent', '/verysilent'], mode: ProcessStartMode.detached);
          _statusMessage = 'Instalador lanzado. La app se cerrara...';
          notifyListeners();
          Timer(const Duration(seconds: 2), () => exit(0));
        }
      } else if (platform == 'macos_intel' || platform == 'macos_arm') {
        await Process.start('open', [filePath], mode: ProcessStartMode.detached);
        _statusMessage = 'Instalador lanzado. La app se cerrara...';
        notifyListeners();
        Timer(const Duration(seconds: 2), () => exit(0));
      } else if (platform == 'linux') {
        await Process.run('chmod', ['+x', filePath]);
        await Process.start(filePath, [], mode: ProcessStartMode.detached);
        _statusMessage = 'Instalador lanzado. La app se cerrara...';
        notifyListeners();
        Timer(const Duration(seconds: 2), () => exit(0));
      }
    } catch (e) {
      debugPrint('Install error: $e');
      _statusMessage = 'Error al instalar. Descarga disponible en: $filePath';
      notifyListeners();
    }
  }

  Future<void> installNow() async {
    if (_hasUpdate && !_isDownloading) {
      final data = await LicenseService.fetchPrivateFile('update.json');
      if (data != null) {
        await _downloadUpdate(data);
      }
    }
  }

  Future<void> setAutoInstall(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_install', value);
    _autoInstall = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _downloadTimer?.cancel();
    super.dispose();
  }
}
