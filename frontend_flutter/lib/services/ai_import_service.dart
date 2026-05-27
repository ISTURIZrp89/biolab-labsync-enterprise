import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AiImportResult {
  final bool success;
  final String? error;
  final List<Map<String, dynamic>> entries;

  AiImportResult({required this.success, this.error, this.entries = const []});
}

class AiImportService {
  Future<String> extractText(String path) async {
    final ext = path.split('.').last.toLowerCase();
    final file = File(path);
    if (!await file.exists()) throw Exception('Archivo no encontrado: $path');

    if (ext == 'xlsx' || ext == 'xls') {
      return _extractExcelText(file);
    } else if (ext == 'docx') {
      return _extractDocxText(file);
    } else if (ext == 'pdf') {
      return _extractPdfText(file);
    } else if (['txt', 'csv', 'json', 'log', 'md'].contains(ext)) {
      return await file.readAsString();
    }
    throw Exception('Formato no soportado: .$ext');
  }

  String _extractExcelText(File file) {
    final bytes = file.readAsBytesSync();
    final excel = Excel.decodeBytes(bytes);
    final buffer = StringBuffer();
    for (final sheet in excel.tables.values) {
      buffer.writeln('--- Hoja: ${sheet.name} ---');
      for (final row in sheet.rows) {
        final cells = row.map((c) => c?.value?.toString() ?? '').join('\t');
        buffer.writeln(cells);
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  String _extractDocxText(File file) {
    final bytes = file.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? docXml;
    for (final f in archive) {
      if (f.name == 'word/document.xml') {
        docXml = f;
        break;
      }
    }
    if (docXml == null) throw Exception('Formato DOCX invalido');
    final xml = utf8.decode(docXml.content);
    final exp = RegExp(r'<w:t[^>]*>([^<]+)</w:t>');
    return exp.allMatches(xml).map((m) => m.group(1)?.trim() ?? '').where((t) => t.isNotEmpty).join(' ');
  }

  String _extractPdfText(File file) {
    final bytes = file.readAsBytesSync();
    final content = utf8.decode(bytes, allowMalformed: true);
    final buffer = StringBuffer();

    final parentExp = RegExp(r'\(([^)]*)\)');
    for (final m in parentExp.allMatches(content)) {
      final text = m.group(1) ?? '';
      if (text.length > 2 && text.contains(RegExp(r'[A-Za-z0-9]'))) {
        buffer.write('$text ');
      }
    }

    final streamExp = RegExp(r'BT\s*(.*?)\s*ET', dotAll: true);
    for (final m in streamExp.allMatches(content)) {
      final block = m.group(1) ?? '';
      for (final t in parentExp.allMatches(block)) {
        final text = t.group(1) ?? '';
        if (text.length > 1 && text.contains(RegExp(r'[A-Za-z0-9]'))) {
          buffer.write('$text ');
        }
      }
    }

    final result = buffer.toString().trim();
    if (result.length < 20) throw Exception('No se pudo extraer texto del PDF. El archivo puede ser escaneado o contener solo imagenes.');
    return result;
  }

  Future<AiImportResult> parseWithAi(String text, {String? model}) async {
    if (text.trim().isEmpty) {
      return AiImportResult(success: false, error: 'No hay texto para procesar');
    }

    final systemPrompt = '''
Eres un asistente que extrae datos de reportes de laboratorio.
Analiza el texto de un reporte y extrae cada entrada como un objeto JSON.
Devuelve SOLO un array JSON valido, sin explicaciones ni markdown.

Cada objeto debe tener estos campos si estan disponibles en el texto:
- fecha (formato YYYY-MM-DD)
- responsable (nombre de la persona)
- actividad (descripcion de la actividad)
- descripcion (detalle adicional)
- observaciones (notas o comentarios)
- cajas (numero de cajas)
- tipo_tejido (tipo de tejido)
- viales (numero de viales)
- misid (identificador)
- millones (millones de celulas)
- hora_inicio (HH:MM)
- hora_fin (HH:MM)
- modulo (bitacora, incubadoras, autoclaves, etc.)

Ejemplo de respuesta:
[{"fecha":"2026-01-15","responsable":"Juan Perez","actividad":"Pase de cultivo","modulo":"bitacora"}]
''';

    try {
      final response = await http.post(
        Uri.parse('http://localhost:11434/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model ?? 'llama3.2:3b',
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': 'Texto del reporte:\n\n$text'},
          ],
          'stream': false,
          'options': {'temperature': 0.1, 'num_ctx': 4096, 'num_predict': 2048},
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        return AiImportResult(success: false, error: 'Ollama error: ${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      final content = body['message']['content'] as String? ?? '';

      final cleaned = content.trim();
      final jsonStart = cleaned.indexOf('[');
      final jsonEnd = cleaned.lastIndexOf(']');
      if (jsonStart == -1 || jsonEnd == -1) {
        return AiImportResult(success: false, error: 'La IA no devolvio un array JSON valido. Respuesta: $cleaned');
      }

      final jsonStr = cleaned.substring(jsonStart, jsonEnd + 1);
      final List parsed = jsonDecode(jsonStr);
      final entries = parsed.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return m;
      }).toList();

      return AiImportResult(success: true, entries: entries);
    } on http.ClientException catch (e) {
      return AiImportResult(success: false, error: 'No se pudo conectar a Ollama (http://localhost:11434). Asegurate de que Ollama este corriendo.\n\nDetalle: $e');
    } catch (e) {
      return AiImportResult(success: false, error: 'Error procesando con IA: $e');
    }
  }

  Future<int> saveToPending(List<Map<String, dynamic>> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('pending_bitacora_imports') ?? [];
    final uuid = const Uuid();
    final now = DateTime.now().toIso8601String();
    int saved = 0;

    for (final entry in entries) {
      entry['_import_id'] = uuid.v4();
      entry['_approval_status'] = 'pending';
      entry['_import_date'] = now;
      entry['_source'] = 'ai_import';
      raw.add(jsonEncode(entry));
      saved++;
    }

    await prefs.setStringList('pending_bitacora_imports', raw);
    return saved;
  }
}
