import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'ai_tool.dart';

class ReadTextFileTool extends AiTool {
  @override
  String get name => 'read_text_file';
  @override
  String get description => 'Lee el contenido de un archivo de texto (TXT, CSV, JSON, LOG, MD, etc)';
  @override
  AiToolRole get requiredRole => AiToolRole.laboratorio;
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'path', type: 'string', description: 'Ruta absoluta al archivo'),
    ToolParameter(name: 'max_lines', type: 'integer', description: 'Maximo de lineas a leer (opcional, default 200)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final maxLines = args['max_lines'] as int? ?? 200;
    if (path == null || path.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Ruta de archivo requerida');
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        return ToolResult(success: false, data: '', error: 'Archivo no encontrado: $path');
      }
      final ext = path.split('.').last.toLowerCase();
      if (ext == 'bin' || ext == 'exe' || ext == 'dll' || ext == 'so' || ext == 'dylib') {
        return ToolResult(success: false, data: '', error: 'No se pueden leer archivos binarios');
      }
      final totalLines = await file.readAsLines();
      final content = totalLines.take(maxLines).join('\n');
      final summary = totalLines.length > maxLines
          ? '\n\n[... mostrando $maxLines de ${totalLines.length} lineas totales]'
          : '';
      return ToolResult(success: true, data: '=== $path ===\n$content$summary');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error leyendo archivo: $e');
    }
  }
}

class ReadExcelTool extends AiTool {
  @override
  String get name => 'read_excel';
  @override
  String get description => 'Lee y extrae datos de un archivo Excel (.xlsx, .xls)';
  @override
  AiToolRole get requiredRole => AiToolRole.jefe;
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'path', type: 'string', description: 'Ruta absoluta al archivo Excel'),
    ToolParameter(name: 'sheet', type: 'string', description: 'Nombre de la hoja (opcional, default primera hoja)', required: false),
    ToolParameter(name: 'max_rows', type: 'integer', description: 'Maximo de filas a leer (opcional, default 100)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final sheetName = args['sheet'] as String?;
    final maxRows = args['max_rows'] as int? ?? 100;
    if (path == null || path.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Ruta de archivo requerida');
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        return ToolResult(success: false, data: '', error: 'Archivo no encontrado: $path');
      }
      final bytes = await file.readAsBytes();
      final excel = Excel.decodeBytes(bytes);
      final sheet = sheetName != null
          ? excel[sheetName]
          : excel.tables.values.first;
      if (sheet == null) {
        final names = excel.tables.keys.join(', ');
        return ToolResult(success: false, data: '', error: 'Hoja no encontrada. Hojas disponibles: $names');
      }
      final buffer = StringBuffer();
      buffer.writeln('=== $path ===');
      if (sheetName != null) buffer.writeln('Hoja: $sheetName');
      buffer.writeln('Filas: ${sheet.rows.length}, Columnas: ${sheet.rows.isNotEmpty ? sheet.rows.first.length : 0}');
      buffer.writeln('');
      int count = 0;
      for (final row in sheet.rows) {
        if (count >= maxRows) {
          buffer.writeln('[... ${sheet.rows.length - maxRows} filas mas]');
          break;
        }
        final cells = row.map((c) {
          final v = c?.value?.toString() ?? '';
          return v.length > 50 ? '${v.substring(0, 50)}...' : v;
        }).join(' | ');
        buffer.writeln('F${count + 1}: $cells');
        count++;
      }
      return ToolResult(success: true, data: buffer.toString(), mimeType: 'text/plain');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error leyendo Excel: $e');
    }
  }
}

class ReadDocxTool extends AiTool {
  @override
  String get name => 'read_docx';
  @override
  String get description => 'Extrae el texto real de un archivo Word (.docx) usando el formato ZIP/XML interno';
  @override
  AiToolRole get requiredRole => AiToolRole.jefe;
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'path', type: 'string', description: 'Ruta absoluta al archivo .docx'),
    ToolParameter(name: 'max_chars', type: 'integer', description: 'Maximo de caracteres a extraer (opcional, default 5000)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final maxChars = args['max_chars'] as int? ?? 5000;
    if (path == null || path.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Ruta de archivo requerida');
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        return ToolResult(success: false, data: '', error: 'Archivo no encontrado: $path');
      }
      final bytes = await file.readAsBytes();
      final text = _extractDocxText(bytes, maxChars);
      if (text.trim().isEmpty) {
        return ToolResult(success: true, data: '=== $path ===\n[Documento vacio o sin texto extraible]');
      }
      return ToolResult(success: true, data: '=== $path ===\n$text');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error leyendo DOCX: $e');
    }
  }

  String _extractDocxText(List<int> bytes, int maxChars) {
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docXml;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docXml = f;
        break;
      }
    }
    if (docXml == null) {
      throw Exception('No se encontro word/document.xml en el DOCX (formato invalido)');
    }
    final xml = utf8.decode(docXml.content);
    final text = StringBuffer();
    final exp = RegExp(r'<w:t[^>]*>([^<]+)</w:t>');
    for (final match in exp.allMatches(xml)) {
      final t = match.group(1)?.trim();
      if (t != null && t.isNotEmpty) {
        text.write('$t ');
        if (text.length > maxChars) {
          text.write('\n[... truncado a $maxChars caracteres]');
          break;
        }
      }
    }
    return text.toString();
  }
}

class ListDirectoryTool extends AiTool {
  @override
  String get name => 'list_directory';
  @override
  String get description => 'Lista el contenido de un directorio';
  @override
  AiToolRole get requiredRole => AiToolRole.jefe;
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'path', type: 'string', description: 'Ruta absoluta al directorio'),
    ToolParameter(name: 'pattern', type: 'string', description: 'Filtro glob (ej: *.txt, *.docx) (opcional)', required: false),
    ToolParameter(name: 'max_items', type: 'integer', description: 'Maximo de items a listar (opcional, default 50)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final pattern = args['pattern'] as String?;
    final maxItems = args['max_items'] as int? ?? 50;
    if (path == null || path.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Ruta de directorio requerida');
    }
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return ToolResult(success: false, data: '', error: 'Directorio no encontrado: $path');
      }
      final buffer = StringBuffer();
      buffer.writeln('=== $path ===');
      int count = 0;
      final entities = await dir.list().toList();
      entities.sort((a, b) => a.path.compareTo(b.path));
      for (final entity in entities) {
        if (count >= maxItems) {
          buffer.writeln('[... ${entities.length - maxItems} elementos mas]');
          break;
        }
        final name = entity.path.split(Platform.isWindows ? '\\' : '/').last;
        if (pattern != null && !name.contains(pattern.replaceAll('*', ''))) continue;
        if (entity is Directory) {
          buffer.writeln('[DIR]  $name/');
        } else {
          final stat = await entity.stat();
          final size = stat.size;
          final sizeStr = size > 1048576
              ? '${(size / 1048576).toStringAsFixed(1)} MB'
              : size > 1024
                  ? '${(size / 1024).toStringAsFixed(1)} KB'
                  : '$size B';
          buffer.writeln('[FILE] $name ($sizeStr)');
        }
        count++;
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error listando directorio: $e');
    }
  }
}

class SearchInFilesTool extends AiTool {
  @override
  String get name => 'search_in_files';
  @override
  String get description => 'Busca texto dentro de archivos en un directorio';
  @override
  AiToolRole get requiredRole => AiToolRole.jefe;
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'path', type: 'string', description: 'Ruta del directorio donde buscar'),
    ToolParameter(name: 'query', type: 'string', description: 'Texto a buscar'),
    ToolParameter(name: 'pattern', type: 'string', description: 'Filtro de archivos (ej: *.txt, *.csv) (opcional)', required: false),
    ToolParameter(name: 'max_results', type: 'integer', description: 'Maximo de resultados (opcional, default 20)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final path = args['path'] as String?;
    final query = args['query'] as String?;
    final pattern = args['pattern'] as String?;
    final maxResults = args['max_results'] as int? ?? 20;
    if (path == null || query == null || query.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Ruta y texto de busqueda requeridos');
    }
    try {
      final dir = Directory(path);
      if (!await dir.exists()) {
        return ToolResult(success: false, data: '', error: 'Directorio no encontrado: $path');
      }
      final buffer = StringBuffer();
      buffer.writeln('Buscando "$query" en $path');
      buffer.writeln('');
      int count = 0;
      final results = <String>[];
      await for (final entity in dir.list(recursive: true)) {
        if (count >= maxResults) break;
        if (entity is! File) continue;
        final name = entity.path.split(Platform.isWindows ? '\\' : '/').last;
        if (pattern != null) {
          final pat = pattern.replaceAll('*', '.*');
          if (!name.contains(RegExp(pat))) continue;
        }
        try {
          final content = await entity.readAsString();
          if (content.contains(query)) {
            final relPath = entity.path.replaceFirst(path, '');
            results.add('$relPath: contiene "$query"');
            count++;
          }
        } catch (_) {}
      }
      if (results.isEmpty) {
        buffer.writeln('No se encontraron resultados.');
      } else {
        results.take(maxResults).forEach((r) => buffer.writeln(r));
        if (results.length > maxResults) {
          buffer.writeln('[... ${results.length - maxResults} resultados mas]');
        }
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error en busqueda: $e');
    }
  }
}
