import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'hardware_detector.dart';

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
          url: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf', sizeMB: 2400, backend: 'llama.cpp'),
      ModelInfo(id: 'tinyllama', name: 'TinyLlama 1.1B', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/TheBloke/TinyLlama-1.1B-GGUF/resolve/main/tinyllama-1.1b-q4_k_m.gguf', sizeMB: 700, backend: 'llama.cpp'),
      ModelInfo(id: 'gemma-2b', name: 'Gemma 2B (Google)', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/google/gemma-2b-it-gguf/resolve/main/gemma-2b-it-q4_k_m.gguf', sizeMB: 1500, backend: 'llama.cpp'),
      ModelInfo(id: 'llama-3.1-8b', name: 'Llama 3.1 8B (Meta)', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf', sizeMB: 4900, backend: 'llama.cpp'),
      ModelInfo(id: 'mistral-7b', name: 'Mistral 7B', format: 'gguf', source: 'huggingface',
          url: 'https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2-q4_k_m.gguf', sizeMB: 4300, backend: 'llama.cpp'),
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
        final uri = Uri.parse(model.url);
        final client = HttpClient();
        final request = await client.getUrl(uri);
        final response = await request.close();
        final totalBytes = response.contentLength;
        int receivedBytes = 0;
        final file = File(filePath);
        final sink = file.openWrite();

        await for (final chunk in response) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (totalBytes > 0) {
            final progress = receivedBytes / totalBytes;
            model.downloadProgress = progress;
            _downloadStatus = 'Descargando ${model.name}... ${(progress * 100).toStringAsFixed(1)}%';
          }
          notifyListeners();
        }
        await sink.close();
        client.close();
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
