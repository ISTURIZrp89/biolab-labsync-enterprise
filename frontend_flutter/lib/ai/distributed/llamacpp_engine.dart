import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class LlamacppEngine {
  static const _port = 18080;
  static Process? _serverProcess;
  static bool _isRunning = false;
  static StreamSubscription<String>? _stdoutSub;
  static String _lastModelPath = '';

  static final List<_VersionSource> _versions = [
    _VersionSource('b9360', 'https://github.com/ggml-org/llama.cpp/releases/download/b9360/'),
    _VersionSource('b9357', 'https://github.com/ggml-org/llama.cpp/releases/download/b9357/'),
    _VersionSource('b9354', 'https://github.com/ggml-org/llama.cpp/releases/download/b9354/'),
  ];

  static String get _binaryName {
    if (Platform.isWindows) return 'llama-server.exe';
    return 'llama-server';
  }

  static String get _platformDir {
    if (Platform.isMacOS) {
      if (Platform.numberOfProcessors < 6) return 'macos-x64';
      return 'macos-arm64';
    } else if (Platform.isLinux) return 'ubuntu-x64';
    else if (Platform.isWindows) return 'win-cpu-x64';
    return 'ubuntu-x64';
  }

  static String get _engineDir {
    final home = Platform.environment['HOME'] ?? '.';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '.';
    final sep = Platform.isWindows ? '\\' : '/';
    final base = Platform.isWindows ? localAppData : '$home${sep}.local${sep}share';
    return '$base${sep}biolab-labsync${sep}llamacpp';
  }

  static String get _modelsDir {
    final home = Platform.environment['HOME'] ?? '.';
    final localAppData = Platform.environment['LOCALAPPDATA'] ?? '.';
    final sep = Platform.isWindows ? '\\' : '/';
    if (Platform.isMacOS) {
      return '$home${sep}Library${sep}Application Support${sep}biolab-labsync${sep}Models';
    } else if (Platform.isLinux) {
      return '$home${sep}.local${sep}share${sep}biolab-labsync${sep}Models';
    }
    return '$localAppData${sep}biolab-labsync${sep}Models';
  }

  static String get binaryPath => '$_engineDir${Platform.isWindows ? '\\' : '/'}$_binaryName';
  static bool get isRunning => _isRunning;
  static int get port => _port;

  static Future<void> ensureBinary() async {
    final dir = Directory(_engineDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    if (await File(binaryPath).exists()) {
      final size = await File(binaryPath).length();
      if (size > 100000) return;
      await File(binaryPath).delete();
    }

    for (final version in _versions) {
      try {
        await _downloadAndExtract(version);
        return;
      } catch (e) {
        print('[llamacpp] Fallo con ${version.tag}: $e');
      }
    }
    throw Exception('No se pudo descargar el motor llama.cpp de ninguna fuente. Verifique su conexion a internet.');
  }

  static Future<void> _downloadAndExtract(_VersionSource version) async {
    final url = '${version.baseUrl}llama-${version.tag}-bin-$_platformDir.zip';
    print('[llamacpp] Descargando $url ...');
    final client = http.Client();
    try {
      final response = await client
          .get(Uri.parse(url), headers: {
            'User-Agent': 'BioLab-LABSYNC/1.0', 'Accept': '*/*',
          })
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}');
      }
      if (response.bodyBytes.length < 1000) {
        throw Exception('Archivo demasiado pequeno (${response.bodyBytes.length} bytes)');
      }
      final archive = ZipDecoder().decodeBytes(response.bodyBytes);
      String? cliPath;
      for (final file in archive) {
        if (file.isFile) {
          final name = file.name.split('/').last;
          if (name == _binaryName || name == 'llama-server' || name == 'llama-server.exe') {
            final outPath = binaryPath;
            final outFile = File(outPath);
            await outFile.create(recursive: true);
            await outFile.writeAsBytes(file.content);
            if (!Platform.isWindows) {
              await Process.run('chmod', ['+x', outPath]);
            }
            print('[llamacpp] Extraido server: $outPath (${file.content.length} bytes)');
          }
          if (name == 'llama-cli' || name == 'llama-cli.exe') {
            final cliOut = '$_engineDir${Platform.isWindows ? '\\' : '/'}$name';
            final cliFile = File(cliOut);
            await cliFile.create(recursive: true);
            await cliFile.writeAsBytes(file.content);
            if (!Platform.isWindows) {
              await Process.run('chmod', ['+x', cliOut]);
            }
            cliPath = cliOut;
            print('[llamacpp] Extraido cli: $cliOut (${file.content.length} bytes)');
          }
        }
      }
      if (await File(binaryPath).exists()) return;
      if (cliPath != null) {
        throw Exception('Se extrajo llama-cli pero no $_binaryName');
      }
      throw Exception('No se encontro $_binaryName ni llama-cli en el ZIP');
    } finally {
      client.close();
    }
  }

  static Future<void> startServer({
    required String modelPath,
    String systemPrompt = '',
    int nCtx = 2048,
    int nGpuLayers = 999,
  }) async {
    if (_isRunning) {
      if (modelPath == _lastModelPath) return;
      await stopServer();
    }

    if (!await File(binaryPath).exists()) {
      throw Exception('Motor llama.cpp no encontrado. Use ensureBinary() primero.');
    }
    if (!await File(modelPath).exists()) {
      throw Exception('Modelo no encontrado: $modelPath');
    }

    _lastModelPath = modelPath;

    final args = [
      '-m', modelPath,
      '--host', '127.0.0.1',
      '--port', '$_port',
      '-c', '$nCtx',
      '-ngl', '$nGpuLayers',
      '--cont-batching',
      '-np', '1',
      '--mlock',
    ];

    print('[llamacpp] Iniciando: $binaryPath ${args.join(' ')}');
    _serverProcess = await Process.start(binaryPath, args,
      workingDirectory: _engineDir,
      runInShell: Platform.isWindows,
    );

    _isRunning = true;

    _stdoutSub = _serverProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      print('[llamacpp] $line');
    });

    _serverProcess!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => print('[llamacpp:err] $line'));

    _serverProcess!.exitCode.then((code) {
      print('[llamacpp] Proceso termino codigo $code');
      _isRunning = false;
      _serverProcess = null;
      _stdoutSub?.cancel();
      _stdoutSub = null;
    });

    await _waitForServer();
  }

  static Future<void> _waitForServer({Duration timeout = const Duration(seconds: 120)}) async {
    final start = DateTime.now();
    while (DateTime.now().difference(start) < timeout) {
      try {
        final client = http.Client();
        try {
          final resp = await client.get(
            Uri.parse('http://127.0.0.1:$_port/health'),
          ).timeout(const Duration(seconds: 2));
          if (resp.statusCode == 200) {
            print('[llamacpp] Servidor listo');
            return;
          }
        } finally {
          client.close();
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 500));
    }
    // Try once more via /completion endpoint
    try {
      final client = http.Client();
      try {
        final resp = await client.post(
          Uri.parse('http://127.0.0.1:$_port/completion'),
          headers: {'Content-Type': 'application/json'},
          body: '{"prompt":"test","n_predict":1}',
        ).timeout(const Duration(seconds: 5));
        if (resp.statusCode == 200) {
          print('[llamacpp] Servidor listo (confirmado por completion)');
          return;
        }
      } finally {
        client.close();
      }
    } catch (_) {}
    throw TimeoutException('El servidor llama.cpp no respondio en $timeout');
  }

  static Future<String> complete({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.2,
  }) async {
    if (!_isRunning) throw Exception('Motor no disponible');

    final fullPrompt = systemPrompt != null && systemPrompt.isNotEmpty
        ? '$systemPrompt\n\n$prompt'
        : prompt;

    final client = http.Client();
    try {
      final resp = await client.post(
        Uri.parse('http://127.0.0.1:$_port/completion'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': fullPrompt,
          'n_predict': maxTokens,
          'temperature': temperature,
          'cache_prompt': true,
        }),
      ).timeout(const Duration(minutes: 10));

      if (resp.statusCode != 200) {
        throw HttpException('HTTP ${resp.statusCode}: ${resp.body}');
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      return data['content'] as String? ?? '';
    } finally {
      client.close();
    }
  }

  static Future<String> completeStream({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 512,
    double temperature = 0.2,
    void Function(String token)? onToken,
  }) async {
    if (!_isRunning) throw Exception('Motor no disponible');

    final fullPrompt = systemPrompt != null && systemPrompt.isNotEmpty
        ? '$systemPrompt\n\n$prompt'
        : prompt;

    final request = http.Request('POST', Uri.parse('http://127.0.0.1:$_port/completion'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'prompt': fullPrompt,
      'n_predict': maxTokens,
      'temperature': temperature,
      'stream': true,
    });

    final client = http.Client();
    try {
      final streamed = await client.send(request);
      if (streamed.statusCode != 200) {
        final err = await streamed.stream.bytesToString();
        throw HttpException('HTTP ${streamed.statusCode}: $err');
      }

      final buffer = StringBuffer();
      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            final jsonStr = line.substring(6).trim();
            if (jsonStr == '[DONE]') continue;
            try {
              final data = jsonDecode(jsonStr) as Map<String, dynamic>;
              final token = data['content'] as String? ?? '';
              buffer.write(token);
              onToken?.call(token);
            } catch (_) {}
          }
        }
      }
      return buffer.toString();
    } finally {
      client.close();
    }
  }

  static Future<void> stopServer() async {
    if (_serverProcess != null) {
      print('[llamacpp] Deteniendo servidor...');
      try {
        final client = http.Client();
        try {
          await client.post(
            Uri.parse('http://127.0.0.1:$_port/quit'),
          ).timeout(const Duration(seconds: 3));
        } finally {
          client.close();
        }
      } catch (_) {}
      _serverProcess!.kill(ProcessSignal.sigint);
      await _serverProcess!.exitCode.timeout(const Duration(seconds: 5), onTimeout: () => -1);
      _serverProcess = null;
    }
    _isRunning = false;
    _stdoutSub?.cancel();
    _stdoutSub = null;
    print('[llamacpp] Servidor detenido');
  }
}

class _VersionSource {
  final String tag;
  final String baseUrl;
  _VersionSource(this.tag, this.baseUrl);
}
