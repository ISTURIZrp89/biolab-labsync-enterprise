import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class UpdateService extends ChangeNotifier {
  final String backendUrl;
  Timer? _checkTimer;
  Timer? _installTimer;

  bool _hasUpdate = false;
  String _latestVersion = '';
  String _currentVersion = '7.1.0';
  String _releaseNotes = '';
  bool _isMandatory = false;
  bool _isChecking = false;
  bool _isDownloading = false;
  bool _isInstalling = false;
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
  bool get isInstalling => _isInstalling;
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
    if (_isChecking || _isDownloading || _isInstalling) return;

    _isChecking = true;
    _statusMessage = 'Verificando actualizaciones...';
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final platform = _getPlatformString();

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

          if (_autoInstall && _downloadInfo != null) {
            await _downloadAndInstallSilently();
          }
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

  Future<void> _downloadAndInstallSilently() async {
    if (_downloadInfo == null || _isDownloading) return;

    _isDownloading = true;
    _downloadProgress = 0.0;
    _statusMessage = 'Descargando actualizacion...';
    notifyListeners();

    try {
      final url = _downloadInfo!['url'] as String;
      final filename = _downloadInfo!['filename'] as String? ?? 'update';

      if (_downloadInfo!['type'] == 'app_store') {
        _statusMessage = 'Redirigiendo a App Store...';
        notifyListeners();
        return;
      }

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request);
      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final tempDir = await _getTempDirectory();
      final file = File('${tempDir.path}/$filename');
      final sink = file.openWrite();

      await response.stream.listen(
        (chunk) {
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            _downloadProgress = receivedBytes / totalBytes;
            _statusMessage = 'Descargando: ${(_downloadProgress * 100).toStringAsFixed(0)}%';
            notifyListeners();
          }
          sink.add(chunk);
        },
        onDone: () async {
          await sink.close();
          _downloadProgress = 1.0;
          _statusMessage = 'Descarga completada. Instalando...';
          notifyListeners();

          await _installUpdateSilently(file);
        },
        onError: (error) {
          _statusMessage = 'Error en la descarga';
          _isDownloading = false;
          notifyListeners();
        },
      ).asFuture();
    } catch (e) {
      debugPrint('Download error: $e');
      _statusMessage = 'Error al descargar: $e';
      _isDownloading = false;
      notifyListeners();
    }
  }

  Future<void> _installUpdateSilently(File file) async {
    _isInstalling = true;
    _statusMessage = 'Instalando actualizacion...';
    notifyListeners();

    try {
      if (Platform.isWindows) {
        await _installWindows(file);
      } else if (Platform.isMacOS) {
        await _installMacOS(file);
      } else if (Platform.isLinux) {
        await _installLinux(file);
      } else if (Platform.isAndroid) {
        await _installAndroid(file);
      }
    } catch (e) {
      debugPrint('Install error: $e');
      _statusMessage = 'Error en la instalacion: $e';
      _isInstalling = false;
      notifyListeners();
    }
  }

  Future<void> _installWindows(File file) async {
    final filename = file.path.toLowerCase();

    if (filename.endsWith('.exe')) {
      final installerPath = file.path;
      final appDir = await getApplicationSupportDirectory();
      final installDir = appDir.parent.path;

      final result = await Process.run(
        installerPath,
        ['/SILENT', '/NORESTART', '/DIR="$installDir"', '/SUPPRESSMSGBOXES'],
        runInShell: true,
      );

      if (result.exitCode == 0 || result.exitCode == 3010) {
        _statusMessage = 'Actualizacion instalada. Reiniciando...';
        notifyListeners();

        await Future.delayed(const Duration(seconds: 2));

        final exeName = 'biolab_labsync.exe';
        final newExe = File('$installDir\\$exeName');
        if (await newExe.exists()) {
          await Process.start(newExe.path, [], runInShell: true);
          exit(0);
        }
      }
    } else if (filename.endsWith('.zip')) {
      final appDir = await getApplicationSupportDirectory();
      final installDir = appDir.parent.path;

      await Process.run(
        'powershell',
        ['-Command', 'Expand-Archive', '-Path', file.path, '-DestinationPath', installDir, '-Force'],
        runInShell: true,
      );

      _statusMessage = 'Actualizacion instalada. Reiniciando...';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));

      final exeName = 'biolab_labsync.exe';
      final newExe = File('$installDir\\$exeName');
      if (await newExe.exists()) {
        await Process.start(newExe.path, [], runInShell: true);
        exit(0);
      }
    }
  }

  Future<void> _installMacOS(File file) async {
    final filename = file.path.toLowerCase();

    if (filename.endsWith('.dmg')) {
      final mountResult = await Process.run('hdiutil', ['attach', file.path, '-nobrowse', '-quiet']);

      if (mountResult.exitCode == 0) {
        final mountOutput = mountResult.stdout.toString();
        final mountPath = mountOutput.split('\n').last.trim();

        if (mountPath.isNotEmpty) {
          await Process.run('cp', ['-R', '$mountPath/BioLab LABSYNC.app', '/Applications/']);
          await Process.run('hdiutil', ['detach', mountPath, '-quiet']);
        }
      }

      _statusMessage = 'Actualizacion instalada. Reiniciando...';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    } else if (filename.endsWith('.zip')) {
      await Process.run('unzip', ['-o', file.path, '-d', '/Applications/']);

      _statusMessage = 'Actualizacion instalada. Reiniciando...';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));
      exit(0);
    }
  }

  Future<void> _installLinux(File file) async {
    final filename = file.path.toLowerCase();

    if (filename.endsWith('.appimage')) {
      final appDir = await getApplicationSupportDirectory();
      final installPath = '${appDir.path}/BioLab-LABSYNC.AppImage';

      await file.copy(installPath);
      await Process.run('chmod', ['+x', installPath]);

      _statusMessage = 'Actualizacion instalada. Reiniciando...';
      notifyListeners();
      await Future.delayed(const Duration(seconds: 2));

      await Process.start(installPath, []);
      exit(0);
    } else if (filename.endsWith('.deb')) {
      final result = await Process.run(
        'pkexec',
        ['dpkg', '-i', file.path],
        runInShell: true,
      );

      if (result.exitCode == 0) {
        _statusMessage = 'Actualizacion instalada. Reiniciando...';
        notifyListeners();
        await Future.delayed(const Duration(seconds: 2));
        exit(0);
      }
    }
  }

  Future<void> _installAndroid(File file) async {
    await Process.run(
      'am',
      [
        'start',
        '-a', 'android.intent.action.VIEW',
        '-d', 'file://${file.path}',
        '-t', 'application/vnd.android.package-archive',
      ],
    );
  }

  Future<Directory> _getTempDirectory() async {
    return await getTemporaryDirectory();
  }

  String _getPlatformString() {
    if (kIsWeb) return 'web';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return 'unknown';
  }

  Future<void> setAutoInstall(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_install', value);
    _autoInstall = value;
    notifyListeners();
  }

  Future<void> installNow() async {
    if (_downloadInfo != null && _hasUpdate) {
      await _downloadAndInstallSilently();
    }
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    _installTimer?.cancel();
    super.dispose();
  }
}
