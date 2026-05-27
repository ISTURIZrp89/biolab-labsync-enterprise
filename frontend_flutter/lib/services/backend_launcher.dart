import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class BackendLauncher {
  static Process? _process;
  static bool _isStarted = false;

  static String get _executableName {
    if (Platform.isWindows) return 'labsync-backend.exe';
    return 'labsync-backend';
  }

  static String get _backendDir {
    try {
      final appDir = p.dirname(Platform.resolvedExecutable);
      return p.join(appDir, 'backend');
    } catch (_) {
      return '';
    }
  }

  static String get _backendPath => _backendDir.isEmpty ? '' : p.join(_backendDir, _executableName);

  static Future<void> start({Duration timeout = const Duration(seconds: 15)}) async {
    if (_isStarted) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_backendPath.isEmpty || !File(_backendPath).existsSync()) return;

    print('[backend] Iniciando desde $_backendPath');
    try {
      _process = await Process.start(
        _backendPath,
        ['--port', '8000', '--host', '127.0.0.1'],
        workingDirectory: _backendDir,
        environment: {
          'DATABASE_URL': 'sqlite:///${p.join(_backendDir, 'labsync.db')}',
          'SYNC_SERVER_PORT': '8000',
          'CORS_ORIGINS': '*',
        },
      );
    } catch (e) {
      print('[backend] Error al iniciar proceso: $e');
      return;
    }

    _process!.stdout.transform(utf8.decoder).listen((l) {});
    _process!.stderr.transform(utf8.decoder).listen((l) {});
    _process!.exitCode.then((code) {
      print('[backend] Proceso termino codigo $code');
      _isStarted = false;
      _process = null;
    });

    await _waitForHealth(timeout: timeout);
    _isStarted = true;
    print('[backend] Listo');
  }

  static Future<void> _waitForHealth({Duration timeout = const Duration(seconds: 15)}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      if (_process == null) return;
      try {
        final resp = await http
            .get(Uri.parse('http://127.0.0.1:8000/api/health'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    print('[backend] Timeout esperando health check');
  }

  static Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      await _process!.exitCode.timeout(Duration(seconds: 3), onTimeout: () => -1);
      _process = null;
    }
    _isStarted = false;
  }
}
