import 'dart:io';
import 'package:sqflite/sqflite.dart';
import '../../data/db.dart';
import 'ai_tool.dart';

class QueryDatabaseTool extends AiTool {
  @override
  String get name => 'query_database';
  @override
  String get description => 'Ejecuta consultas SELECT de solo lectura sobre la base de datos local';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'sql', type: 'string', description: 'Consulta SQL (SOLO SELECT, LIMIT 50 automatico)'),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final sql = (args['sql'] as String?).trim();
    if (sql == null || sql.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Consulta SQL requerida');
    }
    if (!sql.toUpperCase().trimLeft().startsWith('SELECT')) {
      return ToolResult(success: false, data: '', error: 'SOLO se permiten consultas SELECT');
    }
    try {
      final db = await LocalDatabase.instance.database;
      final limitedSql = '${sql.trim().replaceAll(RegExp(r';$'), '')} LIMIT 50';
      final results = await db.rawQuery(limitedSql);
      final buffer = StringBuffer();
      buffer.writeln('Resultados: ${results.length}');
      if (results.isNotEmpty) {
        buffer.writeln('Columnas: ${results.first.keys.join(', ')}');
        buffer.writeln('');
        for (int i = 0; i < results.length; i++) {
          final row = results[i];
          final rowStr = row.entries.map((e) {
            final v = e.value?.toString() ?? 'NULL';
            return '${e.key}=${v.length > 60 ? '${v.substring(0, 60)}...' : v}';
          }).join(', ');
          buffer.writeln('$i: $rowStr');
        }
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error en consulta: $e');
    }
  }
}

class GetTableSchemaTool extends AiTool {
  @override
  String get name => 'get_table_schema';
  @override
  String get description => 'Obtiene el esquema de todas las tablas de la base de datos';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'table', type: 'string', description: 'Nombre de tabla especifica (opcional)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final table = args['table'] as String?;
    try {
      final db = await LocalDatabase.instance.database;
      final buffer = StringBuffer();
      if (table != null && table.isNotEmpty) {
        final rows = await db.rawQuery('PRAGMA table_info($table)');
        buffer.writeln('=== Esquema de: $table ===');
        for (final row in rows) {
          buffer.writeln('${row['name']} (${row['type']}) ${row['notnull'] == 1 ? 'NOT NULL' : ''} ${row['pk'] == 1 ? 'PK' : ''}');
        }
      } else {
        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"
        );
        buffer.writeln('=== TABLAS ===');
        for (final t in tables) {
          final name = t['name'] as String;
          final count = (await db.rawQuery('SELECT COUNT(*) as c FROM $name')).first['c'];
          buffer.writeln('$name ($count registros)');
        }
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error obteniendo esquema: $e');
    }
  }
}

class GetAppStatsTool extends AiTool {
  @override
  String get name => 'get_app_stats';
  @override
  String get description => 'Obtiene estadisticas generales de la aplicacion';
  @override
  List<ToolParameter> get parameters => [];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final db = await LocalDatabase.instance.database;
      final buffer = StringBuffer();
      buffer.writeln('=== Estadisticas de BioLab LabSync ===');
      buffer.writeln('');

      final tables = ['form_entries', 'day_closures', 'month_closures', 'sync_queue', 'audit_log', 'users', 'company_info'];
      for (final t in tables) {
        try {
          final count = (await db.rawQuery('SELECT COUNT(*) as c FROM $t')).first['c'];
          buffer.writeln('$t: $count');
        } catch (_) {}
      }
      buffer.writeln('');
      final dbPath = LocalDatabase.instance.currentDbPath ?? 'desconocida';
      buffer.writeln('Ruta DB: $dbPath');
      if (dbPath.isNotEmpty) {
        try {
          final dbFile = File(dbPath);
          if (await dbFile.exists()) {
            buffer.writeln('Tamano DB: ${(await dbFile.length() / 1024).toStringAsFixed(1)} KB');
          }
        } catch (_) {}
      }

      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error obteniendo estadisticas: $e');
    }
  }
}
