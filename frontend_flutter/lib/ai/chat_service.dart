import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<String> generate(String prompt, {String? contextData, String? userId}) async {
    if (_isGenerating) return '';
    _isGenerating = true;
    _statusMessage = 'Procesando...';
    notifyListeners();

    try {
      final systemPrompt = await getSystemPrompt();
      final modelPath = await getModelPath();
      final model = _modelManager.activeModel;

      if (_currentSession == null) {
        createSession(title: prompt.length > 50 ? '${prompt.substring(0, 50)}...' : prompt);
      }

      _addMessage('user', prompt, metadata: userId != null ? {'userId': userId} : null);

      String response;
      if (modelPath.isNotEmpty && await File(modelPath).exists()) {
        response = await _inferWithLlamaCpp(modelPath, prompt, systemPrompt, contextData);
      } else {
        response = _generateFallback(prompt, contextData, model?.name);
      }

      _addMessage('assistant', response);
      _statusMessage = '';
      return response;
    } catch (e) {
      _statusMessage = 'Error: $e';
      return 'Error al generar respuesta: $e';
    } finally {
      _isGenerating = false;
      notifyListeners();
    }
  }

  void _addMessage(String role, String content, {Map<String, String>? metadata}) {
    if (_currentSession == null) return;
    _currentSession!.messages.add(ChatMessage(role: role, content: content, metadata: metadata));
    _saveSessions();
    notifyListeners();
  }

  Future<String> _inferWithLlamaCpp(String modelPath, String prompt, String systemPrompt, String? contextData) async {
    try {
      final fullPrompt = _buildPrompt(prompt, systemPrompt, contextData);
      final result = await Process.run(
        'llama-cli',
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
      throw Exception('llama-cli no encontrado. Instala llama.cpp o usa el modo simulado. ($e)');
    } catch (e) {
      rethrow;
    }
  }

  String _buildPrompt(String userPrompt, String systemPrompt, String? contextData) {
    final buf = StringBuffer();
    buf.writeln('<|system|>');
    buf.writeln(systemPrompt);
    if (contextData != null && contextData.isNotEmpty) {
      buf.writeln('\nContexto del laboratorio:');
      buf.writeln(contextData);
    }
    if (_currentSession != null && _currentSession!.messages.length > 2) {
      final recent = _currentSession!.messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .takeLast(6);
      buf.writeln('\nHistorial reciente:');
      for (final msg in recent) {
        buf.writeln('<|${msg.role}|>');
        buf.writeln(msg.content);
      }
    }
    buf.writeln('\n<|user|>');
    buf.writeln(userPrompt);
    buf.writeln('\n<|assistant|>');
    return buf.toString();
  }

  String _generateFallback(String prompt, String? contextData, String? modelName) {
    _statusMessage = 'Usando modo simulado (sin modelo activo)';
    notifyListeners();

    final promptLower = prompt.toLowerCase();

    if (promptLower.contains('hola') || promptLower.contains('buenos')) {
      return 'Hola! Soy el asistente de BioLab LABSYNC. Puedo ayudarte con registros, reportes, '
          'analisis de datos y mas. ¿En que puedo ayudarte?';
    }
    if (promptLower.contains('reporte') || promptLower.contains('report')) {
      return 'Para generar un reporte:\n'
          '1. Ve a la pestaña Reportes\n'
          '2. Selecciona el modulo y mes deseado\n'
          '3. Elige el formato (PDF o Excel)\n'
          '4. Presiona "Generar"\n\n'
          'Tambien puedes usar /report [modulo] [mes] [año] en el terminal.';
    }
    if (promptLower.contains('cerrar') && (promptLower.contains('dia') || promptLower.contains('día'))) {
      return 'Para cerrar el dia:\n'
          '1. Asegurate de tener todos los registros completos\n'
          '2. Usa el boton "Cerrar dia" en el dashboard\n'
          '3. Agrega notas opcionales\n'
          '4. Confirma el cierre\n\n'
          'El dia se puede reabrir dentro de las 24 horas siguientes.';
    }
    if (promptLower.contains('modelo') || promptLower.contains('model') || promptLower.contains('ia')) {
      final name = modelName ?? 'ninguno activo';
      return 'Modelo activo: $name\n'
          'Puedes gestionar los modelos desde Ajustes > Modelos IA.\n'
          'Modelos disponibles: Phi-3 Mini, Qwen2.5 1.5B, TinyLlama, Gemma 2B, Llama 3.1 8B, Mistral 7B.';
    }
    if (promptLower.contains('bitacora') || promptLower.contains('bitácora')) {
      return 'El modulo Bitacora registra observaciones diarias del laboratorio. '
          'Campos principales: responsable, fecha, observaciones, incidencias, y seguimiento.';
    }
    if (promptLower.contains('sql') || promptLower.contains('consulta')) {
      return 'Puedes ejecutar consultas SQL directamente con el comando:\n'
          '/sql SELECT * FROM form_entries WHERE date = "2024-01-15"\n\n'
          'Ten cuidado con consultas de escritura, se auditara tu usuario.';
    }
    if (promptLower.contains('ayuda') || promptLower.contains('help')) {
      return 'Comandos disponibles:\n'
          '/ask [pregunta] - Consulta general\n'
          '/edit [modulo] [id] - Editar registro\n'
          '/close [fecha] - Cerrar dia\n'
          '/reopen [fecha] - Reabrir dia\n'
          '/report [modulo] [mes] [año] - Generar reporte\n'
          '/export [formato] - Exportar datos\n'
          '/sql [consulta] - Ejecutar SQL\n'
          '/analyze [modulo] - Analizar datos\n'
          '/prompt [texto] - Cambiar system prompt\n'
          '/help - Mostrar esta ayuda';
    }

    if (contextData != null && contextData.isNotEmpty) {
      return 'He revisado el contexto proporcionado (${contextData.length} caracteres). '
          '¿Que te gustaria hacer con esta informacion?\n\n'
          'Puedo ayudarte a:\n'
          '• Analizar los datos\n'
          '• Generar un reporte\n'
          '• Identificar patrones\n'
          '• Responder preguntas especificas';
    }

    return 'Entendido. ¿En que mas puedo ayudarte?\n\n'
        'Puedes pedirme:\n'
        '• Ayuda con formularios y registros\n'
        '• Generacion de reportes\n'
        '• Analisis de datos\n'
        '• Gestion de modelos IA\n'
        '• Comandos del terminal (/help)';
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
