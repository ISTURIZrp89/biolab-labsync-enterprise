import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'distributed/hardware_detector.dart';
import 'distributed/llamacpp_engine.dart';
import 'distributed/model_manager.dart';

class ChatMessage {
  final String role;
  final String content;
  final DateTime timestamp;
  final Map<String, String>? metadata;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.metadata,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    if (metadata != null) 'metadata': metadata,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    metadata: json['metadata'] as Map<String, String>?,
  );
}

class ChatSession {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? modelId;
  final Map<String, dynamic>? context;

  ChatSession({
    required this.id,
    required this.title,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.modelId,
    this.context,
  }) : messages = messages ?? [],
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    if (modelId != null) 'modelId': modelId,
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'] as String,
    title: json['title'] as String,
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m as Map<String, dynamic>)).toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
    modelId: json['modelId'] as String?,
  );
}

class ChatService extends ChangeNotifier {
  final ModelManager _modelManager;
  List<ChatSession> _sessions = [];
  ChatSession? _currentSession;
  bool _isGenerating = false;
  bool _ready = false;
  bool _initializing = false;
  String _statusMessage = '';
  static const _sessionsKey = 'ai_chat_sessions';
  static const _systemPromptKey = 'ai_system_prompt';

  ChatService(this._modelManager) {
    _loadSessions();
  }

  List<ChatSession> get sessions => _sessions;
  ChatSession? get currentSession => _currentSession;
  bool get isGenerating => _isGenerating;
  String get statusMessage => _statusMessage;

  String get defaultSystemPrompt => '''
Eres un asistente de laboratorio especializado en biotecnología y control de procesos.
Ayudas al personal del laboratorio con sus tareas diarias: registro de datos, interpretación de resultados, 
solución de problemas técnicos, y generación de reportes.
Responde de manera clara, concisa y profesional en español.
Usa el contexto proporcionado para dar respuestas relevantes al laboratorio.
''';

  Future<String> getSystemPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_systemPromptKey) ?? defaultSystemPrompt;
  }

  Future<void> setSystemPrompt(String prompt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_systemPromptKey, prompt);
  }

  Future<String> getModelPath() async {
    final model = _modelManager.activeModel;
    if (model == null) return '';
    return '${_modelManager.basePath}/${model.id}.${model.format}';
  }

  ChatSession createSession({String? title, Map<String, dynamic>? context}) {
    final session = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title ?? 'Nueva conversacion',
      modelId: _modelManager.activeModel?.id,
      context: context,
    );
    _sessions.insert(0, session);
    _currentSession = session;
    _saveSessions();
    notifyListeners();
    return session;
  }

  void selectSession(String sessionId) {
    _currentSession = _sessions.where((s) => s.id == sessionId).firstOrNull;
    notifyListeners();
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.removeWhere((s) => s.id == sessionId);
    if (_currentSession?.id == sessionId) {
      _currentSession = _sessions.isNotEmpty ? _sessions.first : null;
    }
    _saveSessions();
    notifyListeners();
  }

  Future<void> clearCurrentSession() async {
    if (_currentSession == null) return;
    _currentSession!.messages.clear();
    _saveSessions();
    notifyListeners();
  }

  Future<String> generate(String prompt, {String? contextData, String? userId, void Function(String step)? onThinking}) async {
    if (_isGenerating) return '';
    _isGenerating = true;
    _statusMessage = 'Preparando...';
    onThinking?.call('Preparando...');
    notifyListeners();

    try {
      final systemPrompt = await getSystemPrompt();

      if (_currentSession == null) {
        createSession(title: prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt);
      }

      _addMessage('user', prompt, metadata: userId != null ? {'userId': userId} : null);

      await _ensureReady();

      if (await _isOllamaAvailable()) {
        _statusMessage = 'Usando Ollama...';
        onThinking?.call('Usando Ollama...');
        notifyListeners();
        final response = await _inferWithOllama(prompt, systemPrompt, contextData);
        _addMessage('assistant', response);
        _statusMessage = '';
        return response;
      }

      if (await _isLlamaServerAvailable()) {
        _statusMessage = 'Usando motor IA local...';
        onThinking?.call('Generando respuesta...');
        notifyListeners();
        final response = await _inferWithLlamaServer(systemPrompt, contextData);
        _addMessage('assistant', response);
        _statusMessage = '';
        return response;
      }

      final llamaCli = await _getLlamaCliPath();
      if (llamaCli == null) {
        throw Exception('No hay motor de IA disponible. Ve a Ajustes > Modelos IA para descargar uno.');
      }

      final modelPath = await getModelPath();
      if (modelPath.isEmpty || !await File(modelPath).exists()) {
        throw Exception('No hay modelo descargado. Ve a Ajustes > Modelos IA para descargar un modelo.');
      }

      _statusMessage = 'Procesando con IA local...';
      onThinking?.call('Generando respuesta...');
      notifyListeners();
      final response = await _inferWithLlamaCpp(llamaCli, modelPath, prompt, systemPrompt, contextData);
      _addMessage('assistant', response);
      _statusMessage = '';
      return response;
    } catch (e) {
      _statusMessage = 'Error: $e';
      return '⚠️ Error: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  Future<void> _ensureReady({void Function(String step)? onThinking}) async {
    if (_ready) return;
    if (_initializing) {
      while (_initializing) await Future.delayed(const Duration(milliseconds: 100));
      return;
    }
    _initializing = true;
    try {
      final llamaCli = await _getLlamaCliPath();
      if (llamaCli == null) {
        onThinking?.call('Descargando motor llama.cpp...');
        final ok = await _downloadLlamaCpp();
        if (!ok) {
          throw Exception('No se pudo descargar el motor de IA. Verifica tu conexion a internet.');
        }
      }

      final model = _modelManager.activeModel;
      if (model == null || !model.isDownloaded) {
        onThinking?.call('Seleccionando modelo para tu PC...');
        _statusMessage = 'Seleccionando modelo para tu PC...';
        notifyListeners();
        final hw = await HardwareDetector.detect();
        final selected = await _modelManager.autoSelect(hw);
        if (selected == null) {
          throw Exception('No se pudo instalar un modelo. Ve a Ajustes > Modelos IA.');
        }
      }

      final modelPath = await getModelPath();
      if (modelPath.isEmpty || !await File(modelPath).exists()) {
        throw Exception('No hay modelo descargado. Ve a Ajustes > Modelos IA.');
      }

      _ready = true;
    } finally {
      _initializing = false;
    }
  }

  Future<void> initialize() => _ensureReady();

  Future<String?> _getLlamaCliPath() async {
    final basePath = _modelManager.basePath;
    final exe = Platform.isWindows ? '.exe' : '';
    final paths = [
      'llama-cli$exe',
      '$basePath/llama-cli$exe',
    ];
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'] ?? '.';
      paths.add('$localAppData\\biolab-labsync\\llamacpp\\llama-cli$exe');
    } else {
      final home = Platform.environment['HOME'] ?? '.';
      paths.add('$home/.local/share/biolab-labsync/llamacpp/llama-cli$exe');
      paths.add('$home/Library/Application Support/biolab-labsync/llamacpp/llama-cli$exe');
    }
    for (final p in paths) {
      try {
        if (await File(p).exists()) return File(p).absolute.path;
      } catch (_) {}
    }
    try {
      final which = await Process.run(Platform.isWindows ? 'where' : 'which', ['llama-cli']);
      if (which.exitCode == 0) return which.stdout.toString().trim();
    } catch (_) {}
    return null;
  }

  Future<bool> _downloadLlamaCpp() async {
    try {
      _statusMessage = 'Verificando motor llama.cpp...';
      notifyListeners();

      await LlamacppEngine.ensureBinary();
      final cliPath = await _getLlamaCliPath();
      if (cliPath != null) return true;

      final basePath = _modelManager.basePath;
      final dir = Directory(basePath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final exe = Platform.isWindows ? '.exe' : '';
      final binaryName = 'llama-cli$exe';

      final versions = [
        'b9360', 'b9357', 'b9354',
      ];
      String? platformDir;
      if (Platform.isLinux) platformDir = 'ubuntu-x64';
      else if (Platform.isMacOS) {
        platformDir = Platform.numberOfProcessors < 6 ? 'macos-x64' : 'macos-arm64';
      } else if (Platform.isWindows) platformDir = 'win-cpu-x64';

      if (platformDir == null) return false;

      for (final tag in versions) {
        try {
          final url = 'https://github.com/ggml-org/llama.cpp/releases/download/$tag/llama-${tag}-bin-$platformDir.zip';
          _statusMessage = 'Descargando motor IA ($tag)...';
          notifyListeners();

          final zipPath = '$basePath/llama.zip';
          final client = HttpClient();
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();
          final file = File(zipPath);
          await file.openWrite().addStream(response);
          client.close();

          final zipBytes = await File(zipPath).readAsBytes();
          final archive = ZipDecoder().decodeBytes(zipBytes);
          for (final entry in archive) {
            if (!entry.isFile) continue;
            final entryName = entry.name.split('/').last;
            if (entryName == binaryName || entryName == 'llama-cli' || entryName == 'llama-cli.exe') {
              final outPath = '$basePath/$binaryName';
              await File(outPath).writeAsBytes(entry.content);
              if (!Platform.isWindows) {
                await Process.run('chmod', ['+x', outPath]);
              }
              await File(zipPath).delete();
              if (await File(outPath).exists()) return true;
            }
          }
          await File(zipPath).delete();
        } catch (e) {
          print('[chat] Fallo con $tag: $e');
        }
      }
      _statusMessage = 'Error: No se pudo descargar el motor IA de ninguna fuente';
      notifyListeners();
      return false;
    } catch (e) {
      _statusMessage = 'Error descargando motor IA: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> _isOllamaAvailable() async {
    try {
      final response = await http.get(Uri.parse('http://localhost:11434/api/tags')).timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  String _ollamaModelName(ModelInfo? model) {
    if (model == null) return 'llama3.2:3b';
    switch (model.id) {
      case 'phi-3-mini': return 'phi3:mini';
      case 'qwen2.5-1.5b': return 'qwen2.5:1.5b';
      case 'tinyllama': return 'tinyllama:latest';
      case 'gemma-2b': return 'gemma:2b';
      case 'llama-3.1-8b': return 'llama3.1:8b';
      case 'mistral-7b': return 'mistral:7b';
      default: return 'llama3.2:3b';
    }
  }

  Future<String> _inferWithOllama(String prompt, String systemPrompt, String? contextData) async {
    try {
      final modelName = _ollamaModelName(_modelManager.activeModel);

      final messages = [
        {'role': 'system', 'content': systemPrompt},
      ];

      if (contextData != null && contextData.isNotEmpty) {
        messages.add({'role': 'system', 'content': 'Contexto del laboratorio:\n$contextData'});
      }

      if (_currentSession != null && _currentSession!.messages.length > 2) {
        final recent = _currentSession!.messages
            .where((m) => m.role == 'user' || m.role == 'assistant')
            .takeLast(8);
        for (final msg in recent) {
          messages.add({'role': msg.role, 'content': msg.content});
        }
      }

      messages.add({'role': 'user', 'content': prompt});

      final body = jsonEncode({
        'model': modelName,
        'messages': messages,
        'stream': false,
        'options': {
          'temperature': 0.7,
          'num_ctx': 4096,
          'num_predict': 1024,
        },
      });

      final response = await http.post(
        Uri.parse('http://localhost:11434/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final reply = data['message'] as Map<String, dynamic>?;
        if (reply != null && reply['content'] is String) {
          return reply['content'] as String;
        }
        return data['response'] as String? ?? 'Sin respuesta del modelo';
      }
      throw Exception('Ollama error ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Ollama tardó demasiado. Verifica que el modelo esté cargado.');
      }
      rethrow;
    }
  }

  Future<bool> _isLlamaServerAvailable() async {
    try {
      final resp = await http.get(
        Uri.parse('http://127.0.0.1:18080/health'),
      ).timeout(const Duration(seconds: 2));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<String> _inferWithLlamaServer(String systemPrompt, String? contextData) async {
    try {
      final messages = <Map<String, String>>[
        {'role': 'system', 'content': systemPrompt},
      ];

      if (contextData != null && contextData.isNotEmpty) {
        messages.add({'role': 'system', 'content': 'Contexto del laboratorio:\n$contextData'});
      }

      if (_currentSession != null && _currentSession!.messages.isNotEmpty) {
        final recent = _currentSession!.messages
            .where((m) => m.role == 'user' || m.role == 'assistant')
            .takeLast(8);
        for (final msg in recent) {
          messages.add({'role': msg.role, 'content': msg.content});
        }
      }

      final body = jsonEncode({
        'messages': messages,
        'temperature': 0.7,
        'max_tokens': 1024,
        'stream': false,
        'cache_prompt': true,
      });

      final response = await http.post(
        Uri.parse('http://127.0.0.1:18080/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final message = choices[0]['message'] as Map<String, dynamic>?;
          if (message != null && message['content'] is String) {
            return message['content'] as String;
          }
        }
        return data['content'] as String? ?? 'Sin respuesta del modelo';
      }

      final fallbackBody = jsonEncode({
        'prompt': messages.map((m) => '${m['role']}: ${m['content']}').join('\n'),
        'n_predict': 512,
        'temperature': 0.7,
        'cache_prompt': true,
      });
      final fallbackRes = await http.post(
        Uri.parse('http://127.0.0.1:18080/completion'),
        headers: {'Content-Type': 'application/json'},
        body: fallbackBody,
      ).timeout(const Duration(seconds: 120));
      if (fallbackRes.statusCode == 200) {
        final data = jsonDecode(fallbackRes.body) as Map<String, dynamic>;
        return data['content'] as String? ?? 'Sin respuesta del modelo';
      }
      throw Exception('llama-server error ${response.statusCode}: ${response.body}');
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('El motor IA tardó demasiado. Verifica que el modelo esté cargado.');
      }
      rethrow;
    }
  }

  void _addMessage(String role, String content, {Map<String, String>? metadata}) {
    if (_currentSession == null) return;
    _currentSession!.messages.add(ChatMessage(role: role, content: content, metadata: metadata));
    _saveSessions();
    notifyListeners();
  }

  Future<String> _inferWithLlamaCpp(String binaryPath, String modelPath, String prompt, String systemPrompt, String? contextData) async {
    try {
      final modelId = _modelManager.activeModel?.id ?? '';
      final fullPrompt = _buildPrompt(prompt, systemPrompt, contextData, modelId: modelId);
      final result = await Process.run(
        binaryPath,
        [
          '-m', modelPath,
          '--prompt', fullPrompt,
          '-n', '512',
          '-t', '4',
          '--temp', '0.7',
          '--ctx-size', '2048',
          '--no-display-prompt',
        ],
      );

      if (result.exitCode == 0) {
        return result.stdout.toString().trim();
      }
      throw Exception('llama-cli exit code ${result.exitCode}: ${result.stderr}');
    } on ProcessException catch (e) {
      throw Exception('Error ejecutando motor IA: $e');
    } catch (e) {
      rethrow;
    }
  }

  String _chatTemplate(String modelId) {
    switch (modelId) {
      case 'phi-3-mini': return 'phi3';
      case 'qwen2.5-1.5b': return 'chatml';
      case 'tinyllama': return 'tinyllama';
      case 'gemma-2b': return 'gemma';
      case 'llama-3.1-8b': return 'llama3';
      case 'mistral-7b': return 'mistral';
      default: return 'chatml';
    }
  }

  String _buildPrompt(String userPrompt, String systemPrompt, String? contextData, {String modelId = ''}) {
    final template = _chatTemplate(modelId);
    String fullSystem = systemPrompt;
    if (contextData != null && contextData.isNotEmpty) {
      fullSystem = '$fullSystem\n\nContexto del laboratorio:\n$contextData';
    }

    String historyText = '';
    if (_currentSession != null && _currentSession!.messages.length > 2) {
      final recent = _currentSession!.messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .takeLast(6)
          .toList();
      for (final msg in recent) {
        final role = msg.role == 'user' ? 'user' : 'assistant';
        switch (template) {
          case 'phi3':
            historyText += '<|$role|>\n${msg.content}<|end|>\n';
            break;
          case 'chatml':
            historyText += '<|im_start|>$role\n${msg.content}<|im_end|>\n';
            break;
          case 'tinyllama':
            historyText += '<|$role|>\n${msg.content}\n';
            break;
          case 'gemma':
            historyText += '<start_of_turn>$role\n${msg.content}<end_of_turn>\n';
            break;
          case 'llama3':
            historyText += '<|start_header_id|>$role<|end_header_id|>\n\n${msg.content}<|eot_id|>\n';
            break;
          case 'mistral':
            if (msg.role == 'user') {
              historyText += '[INST] ${msg.content} [/INST]\n';
            } else {
              historyText += '${msg.content}</s>\n';
            }
            break;
        }
      }
    }

    switch (template) {
      case 'phi3':
        return '<|system|>\n$fullSystem<|end|>\n${historyText}<|user|>\n$userPrompt<|end|>\n<|assistant|>\n';
      case 'chatml':
        return '<|im_start|>system\n$fullSystem<|im_end|>\n${historyText}<|im_start|>user\n$userPrompt<|im_end|>\n<|im_start|>assistant\n';
      case 'tinyllama':
        return '<|system|>\n$fullSystem\n${historyText}<|user|>\n$userPrompt\n<|assistant|>\n';
      case 'gemma':
        return '<bos>$fullSystem\n\n<start_of_turn>user\n$userPrompt<end_of_turn>\n<start_of_turn>model\n';
      case 'llama3':
        return '<|begin_of_text|><|start_header_id|>system<|end_header_id|>\n\n$fullSystem<|eot_id|>\n${historyText}<|start_header_id|>user<|end_header_id|>\n\n$userPrompt<|eot_id|>\n<|start_header_id|>assistant<|end_header_id|>\n\n';
      case 'mistral':
        return '<s>[INST] $fullSystem\n\n${historyText.replaceAll('</s>\n[INST]', '\n')}$userPrompt [/INST]\n';
      default:
        return '<|im_start|>system\n$fullSystem<|im_end|>\n${historyText}<|im_start|>user\n$userPrompt<|im_end|>\n<|im_start|>assistant\n';
    }
  }

  Future<void> _loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_sessionsKey) ?? [];
      _sessions = raw.map((s) => ChatSession.fromJson(jsonDecode(s) as Map<String, dynamic>)).toList();
      if (_sessions.isNotEmpty) {
        _currentSession = _sessions.first;
      }
    } catch (_) {}
  }

  Future<void> _saveSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = _sessions.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_sessionsKey, raw);
    } catch (_) {}
  }

  @override
  void dispose() {
    _saveSessions();
    super.dispose();
  }
}

extension _IterableExtension<T> on Iterable<T> {
  List<T> takeLast(int n) {
    final list = toList();
    if (list.length <= n) return list;
    return list.sublist(list.length - n);
  }
}
