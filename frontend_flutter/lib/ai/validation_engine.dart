import '../domain/form_definitions.dart';

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final List<String> suggestions;

  ValidationResult({
    this.isValid = true,
    this.errors = const [],
    this.warnings = const [],
    this.suggestions = const [],
  });
}

class ValidationEngine {
  ValidationResult validate(Map<String, dynamic> data, FormSectionDef section) {
    final errors = <String>[];
    final warnings = <String>[];
    final suggestions = <String>[];

    final fields = (section['general_fields'] as List?) ?? [];
    for (final f in fields) {
      if (f['required'] == true) {
        final key = f['key'] as String;
        final val = data[key]?.toString() ?? '';
        if (val.isEmpty) {
          errors.add('${f['label'] ?? key} es requerido');
        }
      }
    }

    if (data.containsKey('hora_inicio') && data.containsKey('hora_fin')) {
      final start = data['hora_inicio']?.toString() ?? '';
      final end = data['hora_fin']?.toString() ?? '';
      if (start.isNotEmpty && end.isNotEmpty) {
        try {
          final sParts = start.split(':');
          final eParts = end.split(':');
          final sMin = int.parse(sParts[0]) * 60 + int.parse(sParts[1]);
          final eMin = int.parse(eParts[0]) * 60 + int.parse(eParts[1]);
          if (eMin <= sMin) {
            warnings.add('Hora fin debe ser posterior a hora inicio');
          }
          if (eMin - sMin > 480) {
            warnings.add('Periodo mayor a 8 horas, verificar');
          }
        } catch (_) {}
      }
    }

    final actividades = data['_actividades'] as List? ?? [];
    if (actividades.isNotEmpty) {
      final emptyActs = actividades.where((a) =>
        (a is Map) && a.values.every((v) => v.toString().isEmpty)).length;
      if (emptyActs == actividades.length) {
        suggestions.add('Agregar al menos una actividad con datos');
      }
    }

    final incidencias = data['incidencias'] as String? ?? '';
    if (incidencias.isNotEmpty && incidencias.length < 5) {
      warnings.add('Descripcion de incidencia muy corta, detallar');
    }

    if (data.containsKey('fecha')) {
      final fecha = data['fecha']?.toString() ?? '';
      if (fecha.isNotEmpty) {
        try {
          final dt = DateTime.parse(fecha);
          if (dt.isAfter(DateTime.now().add(const Duration(days: 1)))) {
            warnings.add('Fecha en el futuro, verificar');
          }
        } catch (_) {
          errors.add('Formato de fecha invalido');
        }
      }
    }

    final recursos = data['_recursos'] as List? ?? [];
    for (final r in recursos) {
      if (r is Map) {
        final reactivo = r['reactivo']?.toString() ?? '';
        final lote = r['lote']?.toString() ?? '';
        if (reactivo.isNotEmpty && lote.isEmpty) {
          warnings.add('Reactivo "$reactivo" sin numero de lote');
        }
        if (r.containsKey('caducidad') && r['caducidad']?.toString().isNotEmpty == true) {
          try {
            final cad = DateTime.parse(r['caducidad'].toString());
            if (cad.isBefore(DateTime.now())) {
              errors.add('Reactivo "$reactivo" con fecha de caducidad vencida');
            }
          } catch (_) {}
        }
      }
    }

    return ValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestions: suggestions,
    );
  }

  List<String> validateEntryForClosure(Map<String, dynamic> data) {
    final issues = <String>[];
    final actividades = data['_actividades'] as List? ?? [];
    if (actividades.isEmpty || actividades.every((a) => a is Map && a.values.every((v) => v.toString().isEmpty))) {
      issues.add('Sin actividades registradas');
    }
    if (data['responsable']?.toString().isEmpty == true) {
      issues.add('Sin responsable asignado');
    }
    return issues;
  }
}
