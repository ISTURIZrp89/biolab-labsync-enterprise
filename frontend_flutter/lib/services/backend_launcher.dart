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
    final appDir = p.dirname(Platform.resolvedExecutable);
    return p.join(appDir, 'backend');
  }

  static String get _backendPath => p.join(_backendDir, _executableName);

  static Future<void> start({Duration timeout = const Duration(seconds: 30)}) async {
    if (_isStarted) return;

    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      print('[backend] Skip: no es desktop');
      return;
    }

    if (!File(_backendPath).existsSync()) {
      print('[backend] No encontrado en $_backendPath — modo external backend');
      return;
    }

    print('[backend] Iniciando desde $_backendPath');
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

    _process!.stdout.transform(utf8.decoder).listen((l) => print('[backend:out] $l'));
    _process!.stderr.transform(utf8.decoder).listen((l) => print('[backend:err] $l'));
    _process!.exitCode.then((code) {
      print('[backend] Proceso termino codigo $code');
      _isStarted = false;
      _process = null;
    });

    await _waitForHealth(timeout: timeout);
    _isStarted = true;
    print('[backend] Listo en http://localhost:8000');
  }

  static Future<void> _waitForHealth({Duration timeout = const Duration(seconds: 30)}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      try {
        final resp = await http
            .get(Uri.parse('http://127.0.0.1:8000/api/health'))
            .timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200) return;
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    throw TimeoutException('Backend no respondio en $timeout');
  }

  static Future<void> stop() async {
    if (_process != null) {
      _process!.kill();
      await _process!.exitCode.timeout(Duration(seconds: 3), onTimeout: () => null);
      _process = null;
    }
    _isStarted = false;
  }
}
