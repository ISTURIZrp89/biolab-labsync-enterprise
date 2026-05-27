import 'dart:convert';
import 'ai_tool.dart';
import 'file_tools.dart';
import 'database_tools.dart';
import 'diagnostic_tools.dart';

class ToolRegistry {
  final Map<String, AiTool> _tools = {};

  ToolRegistry() {
    _registerDefaults();
  }

  void _registerDefaults() {
    _register(ReadTextFileTool());
    _register(ReadExcelTool());
    _register(ReadDocxTool());
    _register(ListDirectoryTool());
    _register(SearchInFilesTool());
    _register(QueryDatabaseTool());
    _register(GetTableSchemaTool());
    _register(GetAppStatsTool());
    _register(CheckDataIntegrityTool());
    _register(GetErrorLogTool());
    _register(GetClosureStatusTool());
    _register(GetSyncStatusTool());
    _register(ValidateDayCompletionTool());
    _register(SystemInfoTool());
    _register(RunSqlTool());
    _register(BackupDatabaseTool());
    _register(RetrySyncTool());
  }

  void _register(AiTool tool) {
    _tools[tool.name] = tool;
  }

  AiTool? get(String name) => _tools[name];
  List<AiTool> get all => _tools.values.toList();

  Future<ToolResult> execute(String name, Map<String, dynamic> args) async {
    final tool = _tools[name];
    if (tool == null) {
      return ToolResult(success: false, data: '', error: 'Herramienta desconocida: $name');
    }
    return tool.execute(args);
  }

  String get toolsDescription {
    final buffer = StringBuffer();
    buffer.writeln('HERRAMIENTAS DISPONIBLES (nombre: descripcion):');
    for (final tool in _tools.values) {
      final params = tool.parameters.map((p) => p.required ? p.name : "${p.name}?").join(', ');
      buffer.writeln('- ${tool.name}: ${tool.description} [$params]');
    }
    buffer.writeln('');
    buffer.writeln('Formato: [HERRAMIENTA] nombre {"arg":"val"} [/HERRAMIENTA]');
    buffer.writeln('Ej: [HERRAMIENTA] read_text_file {"path":"C:\\\\archivo.txt","max_lines":50} [/HERRAMIENTA]');
    return buffer.toString();
  }

  List<Map<String, dynamic>> toJson() => _tools.values.map((t) => t.toJson()).toList();
}

class ToolCallParser {
  static List<ParsedToolCall> parseToolCalls(String text) {
    final results = <ParsedToolCall>[];
    final regex = RegExp(
      r'\[HERRAMIENTA\]\s*(\w+)\s*\n(.*?)\n\s*\[/HERRAMIENTA\]',
      dotAll: true,
    );
    for (final match in regex.allMatches(text)) {
      final name = match.group(1)?.trim() ?? '';
      final argsStr = match.group(2)?.trim() ?? '{}';
      try {
        final args = argsStr.isNotEmpty
            ? Map<String, dynamic>.from(jsonDecode(argsStr) as Map)
            : <String, dynamic>{};
        results.add(ParsedToolCall(name: name, arguments: args));
      } catch (_) {
        results.add(ParsedToolCall(name: name, arguments: {}, rawArgs: argsStr));
      }
    }
    return results;
  }

  static String stripToolCalls(String text) {
    return text.replaceAll(
      RegExp(r'\[HERRAMIENTA\].*?\[/HERRAMIENTA\]', dotAll: true),
      '',
    ).trim();
  }
}

class ParsedToolCall {
  final String name;
  final Map<String, dynamic> arguments;
  final String? rawArgs;
  ParsedToolCall({required this.name, required this.arguments, this.rawArgs});
}
