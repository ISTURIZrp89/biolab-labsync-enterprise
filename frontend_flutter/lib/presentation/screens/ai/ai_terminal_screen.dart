import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../ai/chat_service.dart';
import '../../../ai/distributed/model_manager.dart';
import '../../../data/db.dart';
import '../../../security/auth_service.dart';
import '../../../services/closure_service.dart';
import '../../../theme/omni_theme.dart';
import '../../../services/audit_service.dart';
import '../../widgets/update_dialog.dart';

const _terminalGreen = Color(0xFF00FF41);
const _terminalAmber = Color(0xFFFFB000);
const _terminalRed = Color(0xFFFF3333);
const _terminalBlue = Color(0xFF00BFFF);
const _terminalBg = Color(0xFF0A0A0A);
const _terminalDim = Color(0xFF204020);

class AiTerminalScreen extends StatefulWidget {
  const AiTerminalScreen({super.key});

  @override
  State<AiTerminalScreen> createState() => _AiTerminalScreenState();
}

class _AiTerminalScreenState extends State<AiTerminalScreen> with TickerProviderStateMixin {
  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollCtrl = ScrollController();
  List<_TerminalLine> _lines = [];
  List<String> _history = [];
  int _historyIndex = -1;
  bool _processing = false;
  String _currentDir = '/';
  Timer? _statusTimer;
  String _dragOverMsg = '';

  @override
  void initState() {
    super.initState();
    _addLine('BioLab LABSYNC AI Terminal v1.0.0', color: _terminalGreen, bold: true);
    _addLine('Type /help for available commands', color: _terminalAmber);
    _addLine('─' * 50, color: _terminalDim);
    _initAiEngine();
  }

  Future<void> _initAiEngine() async {
    final chat = context.read<ChatService>();
    try {
      await chat.initialize();
    } catch (_) {
      _addLine('IA no disponible (ve a Ajustes > Modelos IA)', color: _terminalRed);
    }
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  void _addLine(String text, {Color? color, bool bold = false, bool italic = false}) {
    setState(() {
      _lines.add(_TerminalLine(text: text, color: color ?? _terminalGreen, bold: bold, italic: italic));
    });
    _scrollDown();
  }

  void _addThinking() {
    _addLine('  ◇ pensando...', color: _terminalDim, italic: true);
  }

  void _removeLast() {
    setState(() {
      if (_lines.isNotEmpty) _lines.removeLast();
    });
  }

  void _addDialog(String prefix, String text, Color color) {
    _addLine('', color: _terminalDim);
    _addLine('  $prefix', color: color);
    final lines = text.split('\n');
    for (final line in lines) {
      _addLine('  │ $line', color: color.withValues(alpha: 0.85));
    }
    _addLine('  └', color: color.withValues(alpha: 0.5));
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 100), curve: Curves.easeOut);
      }
    });
  }

  void _addTable(List<List<String>> rows) {
    if (rows.isEmpty) return;
    final colWidths = <int>[];
    for (var c = 0; c < rows[0].length; c++) {
      colWidths.add(rows.map((r) => r[c].length).reduce((a, b) => a > b ? a : b) + 2);
    }
    for (var r = 0; r < rows.length; r++) {
      final buf = StringBuffer();
      for (var c = 0; c < rows[r].length; c++) {
        buf.write(rows[r][c].padRight(colWidths[c]));
      }
      _addLine(buf.toString(), bold: r == 0);
    }
  }

  Future<void> _processInput(String input) async {
    if (input.trim().isEmpty) return;
    _history.insert(0, input.trim());
    _historyIndex = -1;
    _processing = true;
    setState(() {});

    final isCommand = input.trim().startsWith('/');
    if (!isCommand) {
      _addDialog('Tú', input.trim(), _terminalAmber);
      _addThinking();
    }

    try {
      await _executeCommand(input.trim());
    } catch (e) {
      _removeLast();
      _addLine('  ⚠ Error: $e', color: _terminalRed);
    }

    _processing = false;
    setState(() {});
    _inputFocus.requestFocus();
  }

  Future<void> _executeCommand(String input) async {
    final parts = input.split(' ');
    final cmd = parts[0].toLowerCase();
    final args = parts.skip(1).toList();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    final rol = user?.rol ?? '';
    final isAdmin = auth.canManageUsers || rol == 'ADMIN' || rol == 'administrador' || rol == 'DESARROLLADOR';

    switch (cmd) {
      case '/ask':
        if (!auth.canUseAI) { _addLine('Permiso denegado: no tienes acceso a IA', color: _terminalRed); return; }
        final question = args.join(' ');
        if (question.isEmpty) { _addLine('Uso: /ask [pregunta]', color: _terminalAmber); return; }
        await _handleAsk(question);
        break;

      case '/close':
        if (!auth.canClose) { _addLine('Permiso denegado: no tienes permiso para cerrar dias', color: _terminalRed); return; }
        await _handleClose(args);
        break;

      case '/reopen':
        if (!auth.canReopen) { _addLine('Permiso denegado: no tienes permiso para reabrir dias', color: _terminalRed); return; }
        await _handleReopen(args);
        break;

      case '/report':
        await _handleReport(args);
        break;

      case '/export':
        if (!auth.canExport) { _addLine('Permiso denegado: no tienes permiso para exportar', color: _terminalRed); return; }
        await _handleExport(args);
        break;

      case '/sql':
        if (!isAdmin) { _addLine('Permiso denegado: solo administradores pueden ejecutar SQL', color: _terminalRed); return; }
        await _handleSql(args.join(' '));
        break;

      case '/analyze':
        if (!auth.canUseAI) { _addLine('Permiso denegado: no tienes acceso a IA', color: _terminalRed); return; }
        await _handleAnalyze(args);
        break;

      case '/prompt':
        if (!isAdmin) { _addLine('Permiso denegado: solo administradores pueden cambiar el system prompt', color: _terminalRed); return; }
        await _handlePrompt(args.join(' '));
        break;

      case '/sessions':
        await _handleSessions();
        break;

      case '/clear':
        setState(() => _lines.clear());
        break;

      case '/model':
      case '/modelo':
        await _handleModel();
        break;

      case '/help':
        _showHelp(isAdmin, auth);
        break;

      default:
        if (cmd.startsWith('/')) {
          _addLine('Comando desconocido: $cmd. Usa /help para ver los comandos disponibles.', color: _terminalRed);
        } else {
          await _handleAsk(input);
        }
    }
  }

  Future<void> _handleAsk(String question) async {
    final chat = context.read<ChatService>();
    bool hadThinking = false;
    final response = await chat.generate(
      question,
      onThinking: (step) {
        setState(() {
          if (hadThinking) {
            if (_lines.isNotEmpty) _lines.removeLast();
          }
          _lines.add(_TerminalLine(text: '  🔧 $step', color: _terminalDim, italic: true));
          hadThinking = true;
        });
        _scrollDown();
      },
    );
    if (hadThinking) _removeLast();
    _addDialog('IA', response, _terminalGreen);
  }

  Future<void> _handleClose(List<String> args) async {
    final closureService = context.read<ClosureService>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) { _addLine('Error: usuario no autenticado', color: _terminalRed); return; }

    final date = args.isNotEmpty ? args[0] : DateTime.now().toIso8601String().split('T')[0];
    final notes = args.length > 1 ? args.skip(1).join(' ') : '';

    try {
      _addLine('Cerrando dia $date...', color: _terminalDim, italic: true);
      final db = await LocalDatabase.instance.database;
      final entries = await db.query('form_entries', where: 'date = ?', whereArgs: [date]);
      _addLine('Registros del dia: ${entries.length}', color: _terminalBlue);
      await closureService.closeDay(date, user, notes: notes);
      _addLine('Dia $date cerrado exitosamente', color: _terminalGreen, bold: true);
    } catch (e) {
      _addLine('Error al cerrar dia: $e', color: _terminalRed);
    }
  }

  Future<void> _handleReopen(List<String> args) async {
    final closureService = context.read<ClosureService>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;
    if (user == null) { _addLine('Error: usuario no autenticado', color: _terminalRed); return; }

    final date = args.isNotEmpty ? args[0] : '';
    if (date.isEmpty) { _addLine('Uso: /reopen [YYYY-MM-DD] [motivo]', color: _terminalAmber); return; }
    final motivo = args.length > 1 ? args.skip(1).join(' ') : 'Reapertura via terminal';

    try {
      await closureService.reopenDay(date, user, motivo: motivo);
      _addLine('Dia $date reabierto exitosamente', color: _terminalGreen, bold: true);
    } catch (e) {
      _addLine('Error al reabrir: $e', color: _terminalRed);
    }
  }

  Future<void> _handleReport(List<String> args) async {
    const modules = ['bitacora', 'procesamiento', 'incubadoras', 'ultracongeladores', 'equipos', 'autoclaves', 'solucion_cobre'];
    final module = args.isNotEmpty ? args[0] : '';
    final month = args.length > 1 ? args[1] : DateTime.now().month.toString().padLeft(2, '0');
    final year = args.length > 2 ? args[2] : DateTime.now().year.toString();

    if (module.isNotEmpty && !modules.contains(module)) {
      _addLine('Modulo invalido. Opciones: ${modules.join(", ")}', color: _terminalRed);
      return;
    }

    try {
      final db = await LocalDatabase.instance.database;
      final where = module.isNotEmpty ? 'module = ? AND strftime("%m", date) = ? AND strftime("%Y", date) = ?' : 'strftime("%m", date) = ? AND strftime("%Y", date) = ?';
      final whereArgs = module.isNotEmpty ? [module, month, year] : [month, year];
      final rows = await db.query('form_entries', where: where, whereArgs: whereArgs);

      if (rows.isEmpty) {
        _addLine('Sin registros para ${module.isNotEmpty ? "$module " : ""}$month/$year', color: _terminalAmber);
        return;
      }

      _addLine('Reporte: ${module.isEmpty ? "TODOS" : module.toUpperCase()} - $month/$year', color: _terminalGreen, bold: true);
      _addLine('Total registros: ${rows.length}', color: _terminalBlue);

      final byUser = <String, int>{};
      for (final row in rows) {
        try {
          final data = jsonDecode(row['data_json'] as String) as Map<String, dynamic>;
          final resp = data['responsable'] as String? ?? data['usuario'] as String? ?? 'Desconocido';
          byUser[resp] = (byUser[resp] ?? 0) + 1;
        } catch (_) {}
      }

      _addLine('', color: _terminalDim);
      _addLine('Registros por usuario:', color: _terminalBlue, bold: true);
      for (final entry in byUser.entries) {
        _addLine('  ${entry.key}: ${entry.value}', color: _terminalGreen);
      }
    } catch (e) {
      _addLine('Error al generar reporte: $e', color: _terminalRed);
    }
  }

  Future<void> _handleExport(List<String> args) async {
    final format = args.isNotEmpty ? args[0].toLowerCase() : 'csv';
    if (format != 'csv' && format != 'json') {
      _addLine('Formato invalido. Usa: /export csv o /export json', color: _terminalRed);
      return;
    }

    try {
      _addLine('Exportando datos a $format...', color: _terminalDim, italic: true);
      final db = await LocalDatabase.instance.database;
      final rows = await db.query('form_entries', orderBy: 'date DESC');
      final path = await FilePicker.platform.saveFile(
        fileName: 'biolab_export_${DateTime.now().toIso8601String().split('T')[0]}.$format',
        type: FileType.custom,
        allowedExtensions: [format],
      );

      if (path == null) { _addLine('Exportacion cancelada', color: _terminalAmber); return; }

      if (format == 'csv') {
        final buf = StringBuffer('id,module,date,created_at,status\n');
        for (final row in rows) {
          buf.writeln('${row['id']},${row['module']},${row['date']},${row['created_at']},${row['status']}');
        }
        await File(path).writeAsString(buf.toString());
      } else {
        await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(rows));
      }

      _addLine('Exportado a: $path', color: _terminalGreen, bold: true);
      _addLine('${rows.length} registros exportados', color: _terminalBlue);
    } catch (e) {
      _addLine('Error al exportar: $e', color: _terminalRed);
    }
  }

  Future<void> _handleSql(String query) async {
    if (query.isEmpty) { _addLine('Uso: /sql [SELECT query]', color: _terminalAmber); return; }

    final auditService = context.read<AuditService>();
    final auth = context.read<AuthService>();
    final user = auth.currentUser;

    try {
      final db = await LocalDatabase.instance.database;
      final queryUpper = query.toUpperCase().trim();

      if (queryUpper.startsWith('SELECT') || queryUpper.startsWith('PRAGMA')) {
        final results = await db.rawQuery(query);
        _addLine('Resultados: ${results.length} filas', color: _terminalBlue, bold: true);

        if (results.isNotEmpty) {
          final headers = results.first.keys.toList();
          final rows = [headers, ...results.map((r) => headers.map((h) => r[h]?.toString() ?? 'NULL').toList())];
          _addTable(rows);
        }
      } else if (isReadOnlyQuery(queryUpper)) {
        _addLine('Solo se permiten consultas SELECT en el terminal.', color: _terminalRed);
      } else {
        _addLine('Solo se permiten consultas SELECT. Usa la interfaz grafica para otras operaciones.', color: _terminalRed);
      }

      if (user != null) {
        await auditService.log(
          action: 'SQL_QUERY', type: 'terminal', userId: user.id.toString(),
          userName: user.nombre, details: query.substring(0, 100),
        );
      }
    } catch (e) {
      _addLine('Error SQL: $e', color: _terminalRed);
    }
  }

  bool isReadOnlyQuery(String q) {
    final u = q.toUpperCase().trim();
    return u.startsWith('SELECT') || u.startsWith('PRAGMA') || u.startsWith('EXPLAIN') || u.startsWith('WITH');
  }

  Future<void> _handleAnalyze(List<String> args) async {
    final module = args.isNotEmpty ? args[0] : '';
    if (module.isEmpty) { _addLine('Uso: /analyze [modulo]', color: _terminalAmber); return; }

    try {
      final db = await LocalDatabase.instance.database;
      final where = module.isNotEmpty ? 'module = ?' : null;
      final whereArgs = module.isNotEmpty ? [module] : null;
      final rows = await db.query('form_entries', where: where, whereArgs: whereArgs);

      _addLine('Analizando modulo: ${module.toUpperCase()}', color: _terminalGreen, bold: true);
      _addLine('Total registros: ${rows.length}', color: _terminalBlue);

      final byDate = <String, int>{};
      for (final row in rows) {
        final d = row['date'] as String? ?? '';
        byDate[d] = (byDate[d] ?? 0) + 1;
      }

      _addLine('Registros por dia:', color: _terminalBlue, bold: true);
      final sorted = byDate.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sorted.take(20)) {
        _addLine('  ${entry.key}: ${entry.value}', color: _terminalGreen);
      }
      if (sorted.length > 20) {
        _addLine('  ... y ${sorted.length - 20} dias mas', color: _terminalDim);
      }

      final avg = rows.length / (byDate.length > 0 ? byDate.length : 1);
      _addLine('Promedio registros/dia: ${avg.toStringAsFixed(1)}', color: _terminalBlue);
    } catch (e) {
      _addLine('Error al analizar: $e', color: _terminalRed);
    }
  }

  Future<void> _handlePrompt(String text) async {
    if (text.isEmpty) {
      final chat = context.read<ChatService>();
      final current = await chat.getSystemPrompt();
      _addLine('System prompt actual:', color: _terminalBlue, bold: true);
      for (final line in current.split('\n')) {
        _addLine('  $line', color: _terminalGreen);
      }
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('ai_system_prompt', text);
      _addLine('System prompt actualizado.', color: _terminalGreen, bold: true);
    } catch (e) {
      _addLine('Error al actualizar prompt: $e', color: _terminalRed);
    }
  }

  Future<void> _handleSessions() async {
    final chat = context.read<ChatService>();
    final sessions = chat.sessions;
    if (sessions.isEmpty) {
      _addLine('No hay sesiones activas.', color: _terminalAmber);
      return;
    }

    _addLine('Sesiones disponibles:', color: _terminalBlue, bold: true);
    for (var i = 0; i < sessions.length; i++) {
      final s = sessions[i];
      final isCurrent = chat.currentSession?.id == s.id;
      _addLine('${isCurrent ? ">" : " "} ${i + 1}. ${s.title} (${s.messages.length} msgs)',
          color: isCurrent ? _terminalGreen : _terminalGreen.withValues(alpha: 0.7));
    }
  }

  Future<void> _handleModel() async {
    final mm = context.read<ModelManager>();
    final active = mm.activeModel;
    if (active != null) {
      _addLine('Modelo activo (app):', color: _terminalBlue, bold: true);
      _addLine('  ${active.name} (${active.id})', color: _terminalGreen);
      _addLine('  Backend: ${active.backend}', color: _terminalGreen);
      _addLine('  Tamano: ${active.sizeMB}MB', color: _terminalGreen);
    } else {
      _addLine('No hay modelo seleccionado en la app.', color: _terminalAmber);
    }
    final installed = mm.installedModels;
    if (installed.isNotEmpty) {
      _addLine('', color: _terminalDim);
      _addLine('Modelos instalados (app):', color: _terminalBlue, bold: true);
      for (final m in installed) {
        _addLine('  ${m.id}${m.id == active?.id ? " (activo)" : ""}', color: _terminalGreen);
      }
    }

    try {
      final ollamaRes = await http.get(Uri.parse('http://localhost:11434/api/tags')).timeout(const Duration(seconds: 2));
      if (ollamaRes.statusCode == 200) {
        final ollamaData = jsonDecode(ollamaRes.body);
        final models = ollamaData['models'] as List;
        if (models.isNotEmpty) {
          _addLine('', color: _terminalDim);
          _addLine('Modelos Ollama disponibles:', color: _terminalBlue, bold: true);
          for (final m in models) {
            final name = m['name'] as String;
            final size = m['details']?['parameter_size'] as String? ?? '';
            _addLine('  $name${size.isNotEmpty ? " ($size)" : ""}', color: _terminalGreen);
          }
          _addLine('', color: _terminalDim);
          _addLine('Usa: ollama pull <modelo> para instalar mas modelos.', color: _terminalAmber, italic: true);
        }
      }
    } catch (_) {}
  }

  void _showHelp(bool isAdmin, AuthService auth) {
    _addLine('COMANDOS DISPONIBLES', color: _terminalGreen, bold: true);
    _addLine('', color: _terminalDim);
    _addLine('  /ask [pregunta]    - Consulta al modelo IA', color: auth.canUseAI ? _terminalGreen : _terminalDim);
    _addLine('  /close [fecha]     - Cerrar un dia', color: auth.canClose ? _terminalGreen : _terminalDim);
    _addLine('  /reopen [fecha]    - Reabrir un dia', color: auth.canReopen ? _terminalGreen : _terminalDim);
    _addLine('  /report [mod] [mes] [año] - Ver reporte rapido', color: _terminalGreen);
    _addLine('  /export [csv|json] - Exportar datos a archivo', color: auth.canExport ? _terminalGreen : _terminalDim);
    _addLine('  /sql [query]       - Ejecutar consulta SQL (solo admin)', color: isAdmin ? _terminalRed : _terminalDim);
    _addLine('  /analyze [modulo]  - Analizar datos de un modulo', color: auth.canUseAI ? _terminalGreen : _terminalDim);
    _addLine('  /prompt [texto]    - Ver/cambiar system prompt (solo admin)', color: isAdmin ? _terminalGreen : _terminalDim);
    _addLine('  /model /modelo      - Ver modelo activo', color: _terminalGreen);
    _addLine('  /sessions          - Listar sesiones activas', color: _terminalGreen);
    _addLine('  /clear             - Limpiar pantalla', color: _terminalGreen);
    _addLine('  /help              - Mostrar esta ayuda', color: _terminalGreen);
    _addLine('', color: _terminalDim);
    _addLine('Tambien puedes escribir cualquier texto para conversar con la IA.', color: _terminalAmber, italic: true);
    _addLine('Arrastra archivos al terminal para incluirlos como contexto.', color: _terminalAmber, italic: true);
  }

  Future<void> _handleFileDrop(File file) async {
    try {
      final name = file.path.split('/').last;
      final ext = name.split('.').last.toLowerCase();
      _addLine('Archivo cargado: $name', color: _terminalBlue, bold: true);

      String content;
      if (ext == 'csv' || ext == 'txt' || ext == 'json') {
        content = await file.readAsString();
        _addLine('Contenido (${content.length} chars):', color: _terminalDim);
        final preview = content.length > 2000 ? '${content.substring(0, 2000)}...' : content;
        for (final line in preview.split('\n').take(20)) {
          _addLine('  $line', color: _terminalGreen.withValues(alpha: 0.7));
        }
        if (content.length > 2000) {
          _addLine('  ... (truncado, ${content.length} chars totales)', color: _terminalDim);
        }

        final chat = context.read<ChatService>();
        bool hadFileThinking = false;
        final response = await chat.generate(
          'Analiza el siguiente archivo $name y dame un resumen:',
          contextData: content,
          onThinking: (step) {
            setState(() {
              if (hadFileThinking) {
                if (_lines.isNotEmpty) _lines.removeLast();
              }
              _lines.add(_TerminalLine(text: '  🔧 $step', color: _terminalDim, italic: true));
              hadFileThinking = true;
            });
            _scrollDown();
          },
        );
        if (hadFileThinking) _removeLast();
        for (final line in response.split('\n')) {
          _addLine(line);
        }
      } else {
        _addLine('Tipo de archivo no soportado para analisis: .$ext', color: _terminalAmber);
        _addLine('Formatos aceptados: .csv, .txt, .json', color: _terminalAmber);
      }
    } catch (e) {
      _addLine('Error al leer archivo: $e', color: _terminalRed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();

    return Scaffold(
      backgroundColor: _terminalBg,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1117),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _terminalGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.terminal, size: 18, color: _terminalGreen),
            ),
            const SizedBox(width: 8),
            const Text('AI Terminal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _terminalGreen)),
            if (chat.isGenerating) ...[
              const SizedBox(width: 12),
              SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: _terminalGreen)),
            ],
            const Spacer(),
            Text(chat.statusMessage, style: const TextStyle(fontSize: 10, color: _terminalAmber)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 18, color: _terminalGreen),
            tooltip: 'Sesiones',
            onPressed: () => _handleSessions(),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: _terminalRed),
            tooltip: 'Limpiar pantalla',
            onPressed: () => setState(() => _lines.clear()),
          ),
          IconButton(
            icon: const Icon(Icons.file_upload_outlined, size: 18, color: _terminalBlue),
            tooltip: 'Cargar archivo',
            onPressed: _pickFile,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: DragTarget<File>(
              onWillAcceptWithDetails: (details) {
                setState(() => _dragOverMsg = 'Suelta para cargar archivo');
                return true;
              },
              onLeave: (_) => setState(() => _dragOverMsg = ''),
              onAcceptWithDetails: (details) {
                setState(() => _dragOverMsg = '');
                _handleFileDrop(details.data);
              },
              builder: (_, candidates, rejected) {
                return Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _lines.length,
                      itemBuilder: (_, i) {
                        final line = _lines[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            line.text,
                            style: TextStyle(
                              fontFamily: 'Courier New',
                              fontSize: 12,
                              color: line.color,
                              fontWeight: line.bold ? FontWeight.bold : FontWeight.normal,
                              fontStyle: line.italic ? FontStyle.italic : FontStyle.normal,
                              height: 1.4,
                            ),
                          ),
                        );
                      },
                    ),
                    if (candidates.isNotEmpty && _dragOverMsg.isNotEmpty)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: _terminalGreen.withValues(alpha: 0.05),
                            border: Border.all(color: _terminalGreen, width: 2),
                          ),
                          child: Center(
                            child: Text(_dragOverMsg, style: const TextStyle(fontSize: 18, color: _terminalGreen, fontFamily: 'Courier New')),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1117),
              border: Border(top: BorderSide(color: Color(0xFF1A1A2E))),
            ),
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _terminalGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text('>\$', style: TextStyle(fontSize: 10, color: _terminalGreen, fontFamily: 'Courier New')),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                        if (_history.isNotEmpty) {
                          _historyIndex = (_historyIndex + 1) % _history.length;
                          _inputCtrl.text = _history[_historyIndex];
                          _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _inputCtrl.text.length));
                        }
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                        if (_historyIndex > 0) {
                          _historyIndex--;
                          _inputCtrl.text = _history[_historyIndex];
                        } else {
                          _historyIndex = -1;
                          _inputCtrl.text = '';
                        }
                        _inputCtrl.selection = TextSelection.fromPosition(TextPosition(offset: _inputCtrl.text.length));
                        return KeyEventResult.handled;
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _inputCtrl,
                      focusNode: _inputFocus,
                      enabled: !_processing,
                      style: const TextStyle(fontFamily: 'Courier New', fontSize: 12, color: _terminalGreen, height: 1.5),
                      cursorColor: _terminalGreen,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                      border: InputBorder.none,
                      hintText: 'Escribe un comando o pregunta...',
                      hintStyle: TextStyle(fontFamily: 'Courier New', fontSize: 11, color: Color(0xFF3A5A3A)),
                    ),
                      onSubmitted: (v) {
                        _inputCtrl.clear();
                        _processInput(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await _handleFileDrop(File(result.files.single.path!));
    }
  }
}

class _TerminalLine {
  final String text;
  final Color color;
  final bool bold;
  final bool italic;

  _TerminalLine({
    required this.text,
    this.color = const Color(0xFF00FF41),
    this.bold = false,
    this.italic = false,
  });
}
