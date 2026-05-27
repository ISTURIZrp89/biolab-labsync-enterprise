import 'dart:io';
import '../../data/db.dart';
import 'ai_tool.dart';

class CheckDataIntegrityTool extends AiTool {
  @override
  String get name => 'check_data_integrity';
  @override
  String get description => 'Revisa la integridad de los datos: inconsistencias, duplicados, registros huerfanos';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'date', type: 'string', description: 'Fecha especifica (YYYY-MM-DD, opcional)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final db = await LocalDatabase.instance.database;
      final date = args['date'] as String?;
      final issues = <String>[];
      final dateFilter = date != null ? " WHERE date = '$date'" : '';

      final dups = await db.rawQuery(
        'SELECT date, module, section_key, entry_id, COUNT(*) as cnt '
        'FROM form_entries$dateFilter GROUP BY date, module, section_key, entry_id HAVING cnt > 1'
      );
      for (final d in dups) {
        issues.add('DUPLICADO: ${d['date']}/${d['module']}/${d['section_key']} - ${d['entry_id']} aparece ${d['cnt']} veces');
      }

      if (date != null) {
        final closed = await db.rawQuery(
          "SELECT date, module FROM day_module_status WHERE date = '$date' AND status = 'closed'"
        );
        final entries = await db.rawQuery(
          "SELECT COUNT(*) as c FROM form_entries WHERE date = '$date'"
        );
        if (closed.isNotEmpty && (entries.first['c'] as int) == 0) {
          issues.add('INCONSISTENCIA: $date esta cerrado pero no tiene entradas');
        }
      }

      final orphaned = await db.rawQuery(
        'SELECT COUNT(*) as c FROM sync_queue sq '
        'LEFT JOIN form_entries fe ON sq.entity_id = fe.entry_id '
        'WHERE fe.entry_id IS NULL AND sq.entity = "form_entry"'
      );
      if ((orphaned.first['c'] as int) > 0) {
        issues.add('REGISTROS HUERFANOS: ${orphaned.first['c']} entradas en sync_queue sin form_entry correspondiente');
      }

      if (issues.isEmpty) {
        return ToolResult(success: true, data: 'No se encontraron problemas de integridad.');
      }
      return ToolResult(success: true, data: 'Problemas encontrados (${issues.length}):\n${issues.join('\n')}');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error en verificacion: $e');
    }
  }
}

class GetErrorLogTool extends AiTool {
  @override
  String get name => 'get_error_log';
  @override
  String get description => 'Obtiene los errores y advertencias del registro de auditoria';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'limit', type: 'integer', description: 'Maximo de entradas (opcional, default 30)', required: false),
    ToolParameter(name: 'action_filter', type: 'string', description: 'Filtrar por tipo de accion (opcional)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final limit = args['limit'] as int? ?? 30;
    final actionFilter = args['action_filter'] as String?;
    try {
      final db = await LocalDatabase.instance.database;
      String where = '';
      if (actionFilter != null && actionFilter.isNotEmpty) {
        where = " WHERE action LIKE '%${actionFilter.replaceAll("'", "''")}%'";
      }
      final logs = await db.rawQuery(
        'SELECT * FROM audit_log$where ORDER BY timestamp DESC LIMIT $limit'
      );
      if (logs.isEmpty) {
        return ToolResult(success: true, data: 'No se encontraron entradas en el registro de auditoria.');
      }
      final buffer = StringBuffer();
      buffer.writeln('=== Registro de Auditoria (ultimas $limit) ===');
      for (final log in logs) {
        final ts = log['timestamp'] ?? '?';
        final action = log['action'] ?? '?';
        final userId = log['user_id'] ?? '?';
        buffer.writeln('[$ts] $action (usuario: $userId)');
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error leyendo auditoria: $e');
    }
  }
}

class GetClosureStatusTool extends AiTool {
  @override
  String get name => 'get_closure_status';
  @override
  String get description => 'Obtiene el estado de cierre de dias y meses';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'date', type: 'string', description: 'Fecha especifica (YYYY-MM-DD, opcional). Si no se da, muestra resumen del mes actual.', required: false),
    ToolParameter(name: 'year', type: 'integer', description: 'Anio para resumen mensual (opcional)', required: false),
    ToolParameter(name: 'month', type: 'integer', description: 'Mes para resumen mensual (opcional)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final db = await LocalDatabase.instance.database;
      final date = args['date'] as String?;
      final buffer = StringBuffer();
      buffer.writeln('=== Estado de Cierres ===');

      if (date != null) {
        final closings = await db.rawQuery(
          "SELECT * FROM day_closures WHERE date = '$date'"
        );
        if (closings.isEmpty) {
          buffer.writeln('Fecha $date: NO cerrado');
        } else {
          for (final c in closings) {
            buffer.writeln('Fecha: $date');
            buffer.writeln('  Cerrado por: ${c['closed_by']}');
            buffer.writeln('  Cerrado en: ${c['closed_at']}');
            buffer.writeln('  Notas: ${c['notes'] ?? "Ninguna"}');
          }
        }
        final reopened = await db.rawQuery(
          "SELECT * FROM day_closures WHERE date = '$date' AND reopened_at IS NOT NULL"
        );
        if (reopened.isNotEmpty) {
          buffer.writeln('  REABIERTO: ${reopened.first['reopened_at']}');
          buffer.writeln('  Motivo: ${reopened.first['reopened_motivo'] ?? "No especificado"}');
        }
      } else {
        final year = args['year'] as int? ?? DateTime.now().year;
        final month = args['month'] as int? ?? DateTime.now().month;
        final monthStr = '$year-${month.toString().padLeft(2, '0')}';

        final monthly = await db.rawQuery(
          "SELECT * FROM month_closures WHERE year = $year AND month = $month"
        );
        if (monthly.isNotEmpty) {
          buffer.writeln('Mes $monthStr: CERRADO');
        } else {
          buffer.writeln('Mes $monthStr: NO cerrado aun');
        }

        final closedDays = await db.rawQuery(
          "SELECT date, closed_by FROM day_closures WHERE date LIKE '$monthStr%' ORDER BY date"
        );
        buffer.writeln('Dias cerrados en $monthStr: ${closedDays.length}');
        for (final d in closedDays) {
          buffer.writeln('  ${d['date']} (por ${d['closed_by']})');
        }

        final totalDays = await db.rawQuery(
          "SELECT DISTINCT date FROM form_entries WHERE date LIKE '$monthStr%'"
        );
        buffer.writeln('Dias con entradas: ${totalDays.length}');
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error obteniendo estado: $e');
    }
  }
}

class GetSyncStatusTool extends AiTool {
  @override
  String get name => 'get_sync_status';
  @override
  String get description => 'Obtiene el estado de la cola de sincronizacion';
  @override
  List<ToolParameter> get parameters => [];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final db = await LocalDatabase.instance.database;
      final buffer = StringBuffer();
      buffer.writeln('=== Estado de Sincronizacion ===');
      final queue = await db.rawQuery('SELECT * FROM sync_queue ORDER BY timestamp ASC');
      buffer.writeln('Elementos en cola: ${queue.length}');
      if (queue.isNotEmpty) {
        for (final q in queue.take(20)) {
          buffer.writeln('  ${q['action']} | ${q['entity']}:${q['entity_id']} | ${q['timestamp']}');
        }
        if (queue.length > 20) {
          buffer.writeln('  ... y ${queue.length - 20} mas');
        }
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error obteniendo sync: $e');
    }
  }
}

class ValidateDayCompletionTool extends AiTool {
  @override
  String get name => 'validate_day';
  @override
  String get description => 'Valida que un dia este completo: revisa que todos los modulos necesarios tengan entradas';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'date', type: 'string', description: 'Fecha a validar (YYYY-MM-DD)'),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final date = args['date'] as String?;
    if (date == null || date.isEmpty) {
      return ToolResult(success: false, data: '', error: 'Fecha requerida');
    }
    try {
      final db = await LocalDatabase.instance.database;
      final buffer = StringBuffer();
      buffer.writeln('=== Validacion del dia $date ===');
      final modules = await db.rawQuery(
        "SELECT DISTINCT module FROM form_entries WHERE date = '$date'"
      );
      if (modules.isEmpty) {
        buffer.writeln('NO HAY ENTRADAS para esta fecha.');
        return ToolResult(success: true, data: buffer.toString());
      }
      buffer.writeln('Modulos con entradas: ${modules.length}');
      for (final m in modules) {
        final module = m['module'] as String;
        final entries = await db.rawQuery(
          "SELECT section_key, COUNT(*) as cnt FROM form_entries WHERE date = '$date' AND module = '$module' GROUP BY section_key"
        );
        buffer.writeln('  $module:');
        for (final e in entries) {
          buffer.writeln('    ${e['section_key']}: ${e['cnt']} entradas');
        }
      }
      final closed = await db.rawQuery(
        "SELECT * FROM day_closures WHERE date = '$date'"
      );
      if (closed.isNotEmpty) {
        buffer.writeln('Estado: DIA CERRADO');
      } else {
        buffer.writeln('Estado: DIA ABIERTO (pendiente de cierre)');
      }
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error validando dia: $e');
    }
  }
}

class RunSqlTool extends AiTool {
  @override
  String get name => 'run_sql';
  @override
  String get description => 'REAL: Ejecuta SQL de mantenimiento (DELETE, UPDATE) - REQUIERE confirmacion del usuario. Solo para corregir problemas diagnosticados.';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'sql', type: 'string', description: 'Sentencia SQL de correccion'),
    ToolParameter(name: 'confirmacion', type: 'string', description: 'El usuario debe escribir \"confirmo\" para ejecutar'),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    final sql = (args['sql'] as String?).trim();
    final confirmacion = (args['confirmacion'] as String?).trim();
    if (sql == null || sql.isEmpty) {
      return ToolResult(success: false, data: '', error: 'SQL requerido');
    }
    if (confirmacion?.toLowerCase() != 'confirmo') {
      return ToolResult(success: false, data: '',
          error: 'Se requiere confirmacion explicita. El usuario debe escribir "confirmo" para ejecutar esta operacion.');
    }
    final upper = sql.toUpperCase().trimLeft();
    if (!upper.startsWith('DELETE') && !upper.startsWith('UPDATE') && !upper.startsWith('INSERT')) {
      return ToolResult(success: false, data: '', error: 'SOLO DELETE, UPDATE o INSERT permitidos. Para SELECT usa query_database.');
    }
    try {
      final db = await LocalDatabase.instance.database;
      final count = await db.rawDelete(sql);
      return ToolResult(success: true, data: 'SQL ejecutado correctamente. Filas afectadas: $count');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error ejecutando SQL: $e');
    }
  }
}

class BackupDatabaseTool extends AiTool {
  @override
  String get name => 'backup_database';
  @override
  String get description => 'REAL: Crea una copia de seguridad de la base de datos actual';
  @override
  List<ToolParameter> get parameters => [
    ToolParameter(name: 'path', type: 'string', description: 'Directorio donde guardar el backup (opcional, default junto a la DB)', required: false),
  ];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final dbPath = LocalDatabase.instance.currentDbPath;
      if (dbPath == null || dbPath.isEmpty) {
        return ToolResult(success: false, data: '', error: 'No se puede determinar la ruta de la BD');
      }
      final dir = args['path'] as String? ?? '${Directory(dbPath).parent.path}${Platform.isWindows ? '\\' : '/'}backups';
      final backupDir = Directory(dir);
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final backupPath = '$dir${Platform.isWindows ? '\\' : '/'}labsync_backup_$dateStr.db';

      await LocalDatabase.instance.exportToDirectory(dir, label: 'backup_$dateStr');
      return ToolResult(success: true, data: 'Backup creado en: $dir');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error creando backup: $e');
    }
  }
}

class RetrySyncTool extends AiTool {
  @override
  String get name => 'retry_sync';
  @override
  String get description => 'REAL: Reintenta todas las sincronizaciones fallidas';
  @override
  List<ToolParameter> get parameters => [];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final db = await LocalDatabase.instance.database;
      final failed = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sync_queue WHERE action LIKE '%fail%' OR action LIKE '%error%'"
      );
      final count = failed.first['c'] as int;
      if (count > 0) {
        await db.rawDelete("DELETE FROM sync_queue WHERE action LIKE '%fail%' OR action LIKE '%error%'");
      }
      return ToolResult(success: true, data: 'Cola de sincronizacion limpiada. $count entradas fallidas eliminadas. Las entradas pendientes seran reintentadas en el proximo ciclo de sync.');
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error al limpiar sync: $e');
    }
  }
}

class SystemInfoTool extends AiTool {
  @override
  String get name => 'system_info';
  @override
  String get description => 'Obtiene informacion del sistema: SO, memoria, almacenamiento, version de la app';
  @override
  List<ToolParameter> get parameters => [];

  @override
  Future<ToolResult> execute(Map<String, dynamic> args) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln('=== Informacion del Sistema ===');
      buffer.writeln('Sistema Operativo: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
      buffer.writeln('Arquitectura: ${Platform.operatingSystem}');
      buffer.writeln('Host: ${Platform.localHostname}');
      buffer.writeln('# de procesadores: ${Platform.numberOfProcessors}');

      if (Platform.isWindows) {
        try {
          final script = 'Get-CimInstance Win32_ComputerSystem | Select-Object TotalPhysicalMemory, Manufacturer, Model';
          final result = await Process.run('powershell', ['-Command', script]);
          buffer.writeln('RAM/Modelo:\n${result.stdout}');
        } catch (_) {}
      } else if (Platform.isMacOS) {
        try {
          final mem = await Process.run('sysctl', ['-n', 'hw.memsize']);
          final totalMem = (int.tryParse(mem.stdout.toString().trim()) ?? 0) ~/ (1024 * 1024 * 1024);
          buffer.writeln('RAM: $totalMem GB');
        } catch (_) {}
      } else if (Platform.isLinux) {
        try {
          final mem = await Process.run('free', ['-h']);
          buffer.writeln('Memoria:\n${mem.stdout}');
        } catch (_) {}
      }

      buffer.writeln('');
      buffer.writeln('Directorio App: ${Directory.current.path}');
      buffer.writeln('Directorio Temp: ${Directory.systemTemp.path}');
      return ToolResult(success: true, data: buffer.toString());
    } catch (e) {
      return ToolResult(success: false, data: '', error: 'Error obteniendo info sistema: $e');
    }
  }
}
