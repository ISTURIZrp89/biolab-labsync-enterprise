import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'hardware_detector.dart';
import 'llamacpp_engine.dart';

class ModelInfo {
  final String id;
  final String name;
  final String format;
  final String source;
  final String url;
  final int sizeMB;
  final String version;
  final String backend;
  final bool isDownloaded;
  double downloadProgress;

  ModelInfo({
    required this.id,
    required this.name,
    this.format = 'gguf',
    this.source = 'huggingface',
    required this.url,
    this.sizeMB = 0,
    this.version = '1.0',
    this.backend = 'llama.cpp',
    this.isDownloaded = false,
    this.downloadProgress = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'format': format, 'source': source,
    'url': url, 'sizeMB': sizeMB, 'version': version,
    'backend': backend, 'isDownloaded': isDownloaded,
  };
}

class ModelManager extends ChangeNotifier {
  List<ModelInfo> _availableModels = [];
  List<ModelInfo> _installedModels = [];
  ModelInfo? _activeModel;
  bool _isDownloading = false;
  String _downloadStatus = '';
  Completer<void>? _downloadCompleter;

  static const _modelsKey = 'ai_installed_models';
  static const _activeKey = 'ai_active_model';

  List<ModelInfo> get availableModels => _availableModels;
  List<ModelInfo> get installedModels => _installedModels;
  ModelInfo? get activeModel => _activeModel;
  bool get isDownloading => _isDownloading;
  String get downloadStatus => _downloadStatus;

  String get basePath {
    if (Platform.isMacOS) {
      return '${Platform.environment['HOME'] ?? '.'}/Library/Application Support/biolab-labsync/Models';
    } else if (Platform.isLinux) {
      return '${Platform.environment['HOME'] ?? '.'}/.local/share/biolab-labsync/Models';
    } else {
      return '${Platform.environment['LOCALAPPDATA'] ?? '.'}\\biolab-labsync\\Models';
    }
  }

  ModelManager() {
    _registerDefaultModels();
    _loadInstalled();
  }

  void _registerDefaultModels() {
    _availableModels = [
      ModelInfo(id: 'phi-3-mini', name: 'Phi-3 Mini (Microsoft)', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/QuantFactory/Phi-3-mini-4k-instruct-GGUF/resolve/main/Phi-3-mini-4k-instruct.Q4_K_M.gguf', sizeMB: 2400, backend: 'llama.cpp'),
      ModelInfo(id: 'qwen2.5-1.5b', name: 'Qwen2.5 1.5B (Alibaba)', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf', sizeMB: 980, backend: 'llama.cpp'),
      ModelInfo(id: 'tinyllama', name: 'TinyLlama 1.1B', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/MaziyarPanahi/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/TinyLlama-1.1B-Chat-v1.0.Q4_K_M.gguf', sizeMB: 700, backend: 'llama.cpp'),
      ModelInfo(id: 'gemma-2b', name: 'Gemma 2B (Google)', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/QuantFactory/gemma-2b-it-GGUF/resolve/main/gemma-2b-it.Q4_K_M.gguf', sizeMB: 1500, backend: 'llama.cpp'),
      ModelInfo(id: 'llama-3.1-8b', name: 'Llama 3.1 8B (Meta)', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/QuantFactory/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct.Q4_K_M.gguf', sizeMB: 4900, backend: 'llama.cpp'),
      ModelInfo(id: 'mistral-7b', name: 'Mistral 7B', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/MaziyarPanahi/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/Mistral-7B-Instruct-v0.2.Q4_K_M.gguf', sizeMB: 4300, backend: 'llama.cpp'),
    ];
  }

  Future<void> _loadInstalled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_modelsKey) ?? [];
      _installedModels = raw.map((s) {
        final map = jsonDecode(s) as Map<String, dynamic>;
        _availableModels.firstWhere((m) => m.id == map['id'], orElse: () => ModelInfo(
          id: map['id'] as String, name: map['name'] as String, url: map['url'] as String,
          format: map['format'] as String? ?? 'gguf', sizeMB: map['sizeMB'] as int? ?? 0,
          backend: map['backend'] as String? ?? 'llama.cpp',
        ));
        return ModelInfo(
          id: map['id'] as String, name: map['name'] as String, url: map['url'] as String,
          format: map['format'] as String? ?? 'gguf', sizeMB: map['sizeMB'] as int? ?? 0,
          backend: map['backend'] as String? ?? 'llama.cpp', isDownloaded: true,
        );
      }).toList();
      final activeId = prefs.getString(_activeKey);
      if (activeId != null) {
        _activeModel = _installedModels.where((m) => m.id == activeId).firstOrNull;
      }
    } catch (_) {}
  }

  Future<void> _saveInstalled() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _installedModels.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList(_modelsKey, raw);
    if (_activeModel != null) {
      await prefs.setString(_activeKey, _activeModel!.id);
    }
  }

  static String? get _hfToken => () {
    final t = String.fromEnvironment('HF_TOKEN');
    return t.isNotEmpty ? t : null;
  }();

  Future<String?> _resolveHfRedirect(String url) async {
    final client = http.Client();
    try {
      final req = http.Request('HEAD', Uri.parse(url));
      req.headers.addAll({'User-Agent': 'BioLab-LABSYNC/1.0', 'Accept': '*/*'});
      if (_hfToken != null) req.headers['Authorization'] = 'Bearer $_hfToken';
      final resp = await client.send(req).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 302 || resp.statusCode == 301) {
        final location = resp.headers['location'];
        if (location != null) return location;
      }
      if (resp.statusCode == 200) return url;
      throw HttpException('HTTP ${resp.statusCode}');
    } finally {
      client.close();
    }
  }

  Future<bool> downloadModel(ModelInfo model) async {
    if (_isDownloading) return false;
    _isDownloading = true;
    _downloadStatus = 'Descargando ${model.name}...';
    _downloadCompleter = Completer<void>();
    notifyListeners();

    try {
      final dir = Directory(basePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final filePath = '$basePath/${model.id}.${model.format}';

      if (await File(filePath).exists()) {
        _downloadStatus = 'El modelo ya existe. Verificando...';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 500));
      } else {
        final resolvedUrl = await _resolveHfRedirect(model.url);

        final client = http.Client();
        try {
          final request = http.Request('GET', Uri.parse(resolvedUrl));
          request.headers.addAll({
            'User-Agent': 'BioLab-LABSYNC/1.0',
            'Accept': '*/*',
          });
          if (_hfToken != null) request.headers['Authorization'] = 'Bearer $_hfToken';

          final streamedResponse = await client
              .send(request)
              .timeout(const Duration(seconds: 30));

          if (streamedResponse.statusCode != 200) {
            final body = await streamedResponse.stream.bytesToString();
            throw HttpException(
              'HTTP ${streamedResponse.statusCode}: ${streamedResponse.reasonPhrase}\n'
              'Servidor respondio: ${body.length > 200 ? body.substring(0, 200) : body}',
            );
          }

          final totalBytes = streamedResponse.contentLength ?? 0;
          if (totalBytes > 0 && totalBytes < 10000) {
            final body = await streamedResponse.stream.bytesToString();
            throw HttpException(
              'El servidor devolvio un archivo demasiado pequeno (${totalBytes}b). '
              'Posible pagina de error. Respuesta: ${body.length > 200 ? body.substring(0, 200) : body}',
            );
          }

          int receivedBytes = 0;
          final file = File(filePath);
          final sink = file.openWrite();
          final stopwatch = Stopwatch()..start();
          int lastReport = 0;

          await for (final chunk in streamedResponse.stream) {
            sink.add(chunk);
            receivedBytes += chunk.length;
            if (totalBytes > 0) {
              final progress = receivedBytes / totalBytes;
              model.downloadProgress = progress;
              final speed = receivedBytes / (1024 * 1024) / (stopwatch.elapsedMilliseconds / 1000);
              _downloadStatus = 'Descargando ${model.name}... ${(progress * 100).toStringAsFixed(1)}% '
                  '(${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)}/${(totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB, '
                  '${speed.toStringAsFixed(1)} MB/s)';
            } else {
              final mb = receivedBytes / (1024 * 1024);
              if (mb - lastReport > 10) {
                lastReport = mb.toInt();
                _downloadStatus = 'Descargando ${model.name}... ${mb.toStringAsFixed(0)} MB recibidos';
              }
            }
            notifyListeners();
          }
          await sink.close();
          stopwatch.stop();

          final fileSize = await File(filePath).length();
          if (fileSize < 10000) {
            await File(filePath).delete();
            throw HttpException('Archivo descargado corrupto: solo $fileSize bytes');
          }
        } finally {
          client.close();
        }
      }

      final installed = ModelInfo(
        id: model.id, name: model.name, url: model.url,
        format: model.format, sizeMB: model.sizeMB,
        backend: model.backend, isDownloaded: true,
      );
      _installedModels.removeWhere((m) => m.id == model.id);
      _installedModels.add(installed);
      _activeModel = installed;
      await _saveInstalled();
      _downloadStatus = '${model.name} instalado correctamente';
      notifyListeners();
      return true;
    } catch (e) {
      _downloadStatus = 'Error: $e';
      notifyListeners();
      return false;
    } finally {
      _isDownloading = false;
      _downloadCompleter?.complete();
      _downloadCompleter = null;
      notifyListeners();
    }
  }

  Future<bool> downloadLlamaCppEngine() async {
    _downloadStatus = 'Verificando motor llama.cpp...';
    notifyListeners();
    try {
      await LlamacppEngine.ensureBinary();
      _downloadStatus = 'Motor llama.cpp listo';
      notifyListeners();
      return true;
    } catch (e) {
      _downloadStatus = 'Error al descargar motor llama.cpp: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> startInference(String systemPrompt) async {
    if (_activeModel == null) {
      _downloadStatus = 'Error: No hay modelo activo seleccionado';
      notifyListeners();
      return false;
    }
    final modelPath = '$basePath/${_activeModel!.id}.${_activeModel!.format}';
    if (!await File(modelPath).exists()) {
      _downloadStatus = 'Error: Archivo del modelo no encontrado en $modelPath';
      notifyListeners();
      return false;
    }
    try {
      await LlamacppEngine.ensureBinary();
      await LlamacppEngine.startServer(modelPath: modelPath, systemPrompt: systemPrompt);
      _downloadStatus = 'Motor de inferencia iniciado correctamente';
      notifyListeners();
      return true;
    } catch (e) {
      _downloadStatus = 'Error al iniciar inferencia: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> stopInference() async {
    await LlamacppEngine.stopServer();
    _downloadStatus = 'Motor de inferencia detenido';
    notifyListeners();
  }

  Future<void> deleteModel(String modelId) async {
    _installedModels.removeWhere((m) => m.id == modelId);
    if (_activeModel?.id == modelId) _activeModel = null;
    final filePath = '$basePath/$modelId.gguf';
    try { await File(filePath).delete(); } catch (_) {}
    await _saveInstalled();
    notifyListeners();
  }

  Future<void> setActiveModel(String modelId) async {
    _activeModel = _installedModels.where((m) => m.id == modelId).firstOrNull;
    final prefs = await SharedPreferences.getInstance();
    if (_activeModel != null) {
      await prefs.setString(_activeKey, _activeModel!.id);
    } else {
      await prefs.remove(_activeKey);
    }
    notifyListeners();
  }

  Future<ModelInfo?> autoSelect(HardwareProfile hw) async {
    final recommended = HardwareDetector.recommendedModel(hw);
    final match = _installedModels.where((m) => m.id == recommended).firstOrNull;
    if (match != null) {
      _activeModel = match;
      await _saveInstalled();
      notifyListeners();
      return match;
    }
    if (_installedModels.isNotEmpty) {
      _activeModel = _installedModels.first;
      await _saveInstalled();
      notifyListeners();
      return _activeModel;
    }
    final fallback = _availableModels.where((m) {
      if (hw.tier == 'low') return m.id == 'tinyllama';
      if (hw.tier == 'medium') return m.id == 'gemma-2b';
      return m.id == 'phi-3-mini';
    }).firstOrNull;
    if (fallback != null) {
      await downloadModel(fallback);
      return _activeModel;
    }
    return null;
  }
}
