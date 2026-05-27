import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../ai/distributed/model_manager.dart';
import '../../../ai/distributed/llamacpp_engine.dart';
import '../../../ai/tools/tool_registry.dart';
import '../../../ai/tools/ai_tool.dart';
import '../../../theme/omni_theme.dart';

final ToolRegistry _tools = ToolRegistry();

const String kBaseSystemPrompt = '''
Eres BioLab Supervisor AI, un supervisor tecnico REAL especializado EXCLUSIVAMENTE en laboratorios, bitacoras y control operativo de BioLab LabSync.

SKILLS / CAPACIDADES:

1. LECTURA DE ARCHIVOS
   - Leer archivos Excel (.xlsx): tablas, hojas, datos numericos y texto
   - Leer archivos Word (.docx): documentos con formato, memos, reportes
   - Leer archivos de texto: TXT, CSV, JSON, LOG, MD, XML, HTML, INI, CFG
   - Listar directorios y buscar archivos por nombre o contenido

2. ACCESO A BASE DE DATOS
   - Consultar cualquier tabla de la base de datos SQLite local
   - Ver esquema de tablas, columnas, tipos de datos
   - Obtener estadisticas: numero de registros por tabla, tamano de la BD
   - Ruta de la BD y的健康状态

3. DIAGNOSTICO DEL SISTEMA
   - Detectar duplicados en entradas de bitacora
   - Encontrar registros huerfanos (sync_queue sin form_entry)
   - Identificar dias cerrados sin entradas
   - Revisar el registro de auditoria (errores, advertencias, acciones)
   - Validar estado de cierre diario y mensual
   - Verificar cola de sincronizacion
   - Obtener informacion del hardware y SO

4. ACCIONES DE CORRECCION (requieren confirmacion)
   - Ejecutar SQL de mantenimiento (DELETE/UPDATE) bajo confirmacion explicita
   - Crear backup de la base de datos
   - Limpiar cola de sincronizacion fallida

COMPORTAMIENTO:
- Actua con precision. No inventes informacion.
- Si algo no existe en los datos: dilo claramente.
- Nunca inventes IDs, lotes, pacientes, fechas, resultados, usuarios.
- Si faltan datos, marcalo como "informacion incompleta".
- Prioriza exactitud, estabilidad y trazabilidad sobre velocidad.
- Cuando encuentres un problema: describelo, explica la causa probable, sugiere solucion.
- Responde SIEMPRE en espanol.

INSTRUCCIONES DE USO DE HERRAMIENTAS:
Cuando necesites leer un archivo, consultar la BD o hacer un diagnostico, usa el formato:
[HERRAMIENTA] nombre_de_la_herramienta
{"argumento1": "valor1"}
[/HERRAMIENTA]

IMPORTANTE: Siempre que el usuario te pida leer un archivo, revisar datos o diagnosticar algo, DEBES usar la herramienta correspondiente. No simules ni inventes resultados.
''';

class AiSupervisorScreen extends StatefulWidget {
  const AiSupervisorScreen({super.key});

  @override
  State<AiSupervisorScreen> createState() => _AiSupervisorScreenState();
}

class _AiSupervisorScreenState extends State<AiSupervisorScreen> {
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final List<_ChatMessage> _messages = [];
  bool _processing = false;
  bool _serverReady = false;
  bool _firstMessage = true;

  @override
  void initState() {
    super.initState();
    _addMessage('Sistema', 'BioLab Supervisor AI listo. Herramientas cargadas: ${_tools.all.length}', isSystem: true);
    _checkServer();
  }

  Future<void> _checkServer() async {
    if (LlamacppEngine.isRunning) {
      setState(() => _serverReady = true);
    }
  }

  void _addMessage(String sender, String text, {bool isSystem = false, bool isError = false, bool append = false}) {
    setState(() {
      if (append && _messages.isNotEmpty) {
        final last = _messages.removeLast();
        _messages.add(_ChatMessage(sender: last.sender, text: last.text + text, isSystem: last.isSystem, isError: last.isError));
      } else {
        _messages.add(_ChatMessage(sender: sender, text: text, isSystem: isSystem, isError: isError));
      }
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  String get _systemPrompt {
    return '$kBaseSystemPrompt\n\n${_tools.toolsDescription}';
  }

  Future<void> _sendMessage() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty || _processing) return;
    _inputCtrl.clear();

    _addMessage('Tu', text);
    setState(() => _processing = true);

    try {
      await _ensureServerReady();
      final firstResponse = await _callLlm(text);
      await _handleResponse(firstResponse, text);
    } catch (e) {
      _addMessage('Error', 'Error al procesar: $e', isError: true);
    } finally {
      setState(() => _processing = false);
    }
  }

  Future<void> _ensureServerReady() async {
    if (LlamacppEngine.isRunning) return;
    final manager = context.read<ModelManager>();
    final sep = Platform.isWindows ? '\\' : '/';
    final modelPath = manager.activeModel != null
        ? '${manager.basePath}$sep${manager.activeModel!.id}.${manager.activeModel!.format}'
        : '';
    if (modelPath.isEmpty || !await File(modelPath).exists()) {
      throw Exception('No hay modelo activo instalado. Ve a Gestor de Modelos, descarga e instala un modelo (ej: TinyLlama 700MB).');
    }
    _addMessage('Sistema', 'Iniciando motor de IA...', isSystem: true);
    await LlamacppEngine.ensureBinary();
    await LlamacppEngine.startServer(modelPath: modelPath, systemPrompt: _systemPrompt);
    setState(() => _serverReady = true);
    _addMessage('Sistema', 'Motor listo en puerto ${LlamacppEngine.port}', isSystem: true);
  }

  Future<String> _callLlm(String prompt) async {
    if (!LlamacppEngine.isRunning) {
      throw Exception('Motor no disponible');
    }
    return LlamacppEngine.completeStream(
      prompt: prompt,
      systemPrompt: _systemPrompt,
      maxTokens: 2048,
      temperature: 0.2,
      onToken: (token) {
        if (_firstMessage) {
          _addMessage('BioLab Supervisor AI', token);
          _firstMessage = false;
        } else {
          _addMessage('BioLab Supervisor AI', token, append: true);
        }
      },
    );
  }

  Future<void> _handleResponse(String response, String originalQuery) async {
    _firstMessage = true;
    final calls = ToolCallParser.parseToolCalls(response);

    if (calls.isNotEmpty) {
      _addMessage('Sistema', 'Ejecutando ${calls.length} herramienta(s)...', isSystem: true);
      for (final call in calls) {
        await _executeTool(call, originalQuery);
      }
    }
  }

  Future<void> _executeTool(ParsedToolCall call, String originalQuery) async {
    _addMessage('Sistema', '> Usando: ${call.name}', isSystem: true);
    final result = await _tools.execute(call.name, call.arguments);
    final resultMsg = StringBuffer();
    resultMsg.writeln('Resultado de ${call.name}:');
    if (result.success) {
      resultMsg.writeln(result.data);
      if (result.data.length > 1500) {
        resultMsg.writeln('\n[Resultado extenso: ${result.data.length} caracteres]');
      }
    } else {
      resultMsg.writeln('ERROR: ${result.error}');
    }
    _addMessage('Herramienta', resultMsg.toString(), isSystem: true);

    final analysisPrompt = '''
El usuario pregunto: "$originalQuery"

Se uso la herramienta "${call.name}" con el siguiente resultado:
${result.success ? result.data.substring(0, result.data.length > 2000 ? 2000 : result.data.length) : "Error: ${result.error}"}

${result.success ? 'Con base en este resultado, responde al usuario de manera clara y util.' : 'Explica al usuario el error y sugiere alternativas.'}

IMPORTANTE: Responde en espanol. Si detectaste problemas, enumeralos y sugiere soluciones.
''';

    final analysis = await _callLlm(analysisPrompt);
    final nestedCalls = ToolCallParser.parseToolCalls(analysis);
    if (nestedCalls.isNotEmpty) {
      for (final nc in nestedCalls) {
        await _executeTool(nc, originalQuery);
      }
    }
  }

  Future<void> _toggleServer() async {
    if (LlamacppEngine.isRunning) {
      await LlamacppEngine.stopServer();
      setState(() => _serverReady = false);
      _addMessage('Sistema', 'Motor de inferencia detenido.', isSystem: true);
    } else {
      try {
        setState(() => _processing = true);
        await _ensureServerReady();
      } catch (e) {
        _addMessage('Error', 'No se pudo iniciar el motor: $e', isError: true);
      } finally {
        setState(() => _processing = false);
      }
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OmniTheme.bg950,
      appBar: AppBar(
        title: const Text('BioLab Supervisor AI'),
        backgroundColor: OmniTheme.bg900,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _serverReady ? OmniTheme.green400.withOpacity(0.2) : OmniTheme.red400.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: _serverReady ? OmniTheme.green400 : OmniTheme.red400),
                const SizedBox(width: 4),
                Text(
                  _serverReady ? 'Online' : 'Offline',
                  style: TextStyle(fontSize: 11, color: _serverReady ? OmniTheme.green400 : OmniTheme.red400),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(_serverReady ? Icons.stop : Icons.play_arrow, color: OmniTheme.textSecondary),
            tooltip: _serverReady ? 'Detener motor' : 'Iniciar motor',
            onPressed: _processing ? null : _toggleServer,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.psychology, size: 64, color: OmniTheme.accentBlue.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('BioLab Supervisor AI', style: TextStyle(color: OmniTheme.textMuted, fontSize: 18)),
                        const SizedBox(height: 8),
                        Text('Puedo leer archivos (Excel, Word, TXT), consultar la base de datos,\n'
                            'diagnosticar errores y revisar el estado del sistema.',
                            style: TextStyle(color: OmniTheme.textMuted, fontSize: 12), textAlign: TextAlign.center),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildMessage(_messages[i]),
                  ),
          ),
          if (_processing)
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 4),
              child: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: OmniTheme.accentBlue)),
                  const SizedBox(width: 8),
                  Text('Procesando...', style: TextStyle(color: OmniTheme.textMuted, fontSize: 12)),
                ],
              ),
            ),
          Container(
            color: OmniTheme.bg900,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    enabled: !_processing,
                    style: const TextStyle(color: OmniTheme.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: _serverReady
                          ? 'Ej: lee este archivo, revisa la BD, diagnostica errores...'
                          : 'Inicia el motor primero...',
                      hintStyle: TextStyle(color: OmniTheme.textMuted.withOpacity(0.5)),
                      filled: true,
                      fillColor: OmniTheme.bg800,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: _processing ? OmniTheme.textMuted : OmniTheme.accentBlue),
                  onPressed: _processing ? null : _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(_ChatMessage msg) {
    final isUser = msg.sender == 'Tu';
    final isError = msg.isError;
    final isSystem = msg.isSystem;

    Color bgColor;
    Color textColor;
    String label;

    if (isSystem) {
      bgColor = OmniTheme.bg800;
      textColor = OmniTheme.textMuted;
      label = msg.sender;
    } else if (isError) {
      bgColor = OmniTheme.red400.withOpacity(0.1);
      textColor = OmniTheme.red400;
      label = 'Error';
    } else if (isUser) {
      bgColor = OmniTheme.accentBlue.withOpacity(0.15);
      textColor = OmniTheme.textPrimary;
      label = 'Tu';
    } else {
      bgColor = OmniTheme.bg800;
      textColor = OmniTheme.textPrimary;
      label = msg.sender;
    }

    final isToolResult = msg.sender == 'Herramienta';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * (isToolResult ? 0.95 : 0.8)),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12).copyWith(
              bottomRight: isUser ? const Radius.circular(4) : null,
              bottomLeft: !isUser ? const Radius.circular(4) : null,
            ),
            border: isToolResult ? Border.all(color: OmniTheme.accentBlue.withOpacity(0.3)) : null,
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (isToolResult) ...[
                    Icon(Icons.build, size: 12, color: OmniTheme.accentBlue),
                    const SizedBox(width: 4),
                  ],
                  Text(label, style: TextStyle(
                    color: isError ? OmniTheme.red400 : OmniTheme.accentBlue,
                    fontSize: 10, fontWeight: FontWeight.bold,
                  )),
                ],
              ),
              const SizedBox(height: 4),
              Text(msg.text, style: TextStyle(
                color: textColor,
                fontSize: isToolResult ? 11 : 13,
                fontFamily: isToolResult ? 'monospace' : null,
              )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String sender;
  final String text;
  final bool isSystem;
  final bool isError;
  _ChatMessage({required this.sender, required this.text, this.isSystem = false, this.isError = false});
}
