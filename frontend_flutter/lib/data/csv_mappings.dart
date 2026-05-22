class CsvFieldMapping {
  final String module;
  final String section;
  final String fieldKey;
  final String columnPattern;

  const CsvFieldMapping({
    required this.module,
    required this.section,
    required this.fieldKey,
    required this.columnPattern,
  });
}

class CsvModuleDetector {
  final String moduleKey;
  final String moduleName;
  final String sectionKey;
  final double minScore;
  final List<CsvFieldMapping> mappings;

  const CsvModuleDetector({
    required this.moduleKey,
    required this.moduleName,
    required this.sectionKey,
    this.minScore = 0.3,
    required this.mappings,
  });
}

final List<CsvModuleDetector> csvModuleDetectors = [
  CsvModuleDetector(
    moduleKey: 'equipos',
    moduleName: 'Potenciometro',
    sectionKey: 'potenciometro',
    minScore: 0.3,
    mappings: [
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'fecha', columnPattern: r'(?i)^fecha'),
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'hora_inicio', columnPattern: r'(?i)hora.*inicio'),
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'hora_fin', columnPattern: r'(?i)hora.*fin'),
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'nombre', columnPattern: r'(?i)nomb(re|re abreviado)'),
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'actividad', columnPattern: r'(?i)actividad'),
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'ph_obtenido', columnPattern: r'(?i)ph|calibraci'),
      CsvFieldMapping(module: 'equipos', section: 'potenciometro', fieldKey: 'observaciones', columnPattern: r'(?i)observa'),
    ],
  ),
  CsvModuleDetector(
    moduleKey: 'equipos',
    moduleName: 'Condiciones Ambientales',
    sectionKey: 'condiciones_ambientales',
    minScore: 0.3,
    mappings: [
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'nombre', columnPattern: r'(?i)nomb(re|re abreviado)'),
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'fecha_hora', columnPattern: r'(?i)fecha.*hora|fecha y hora'),
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'temperatura', columnPattern: r'(?i)temperatura'),
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'humedad', columnPattern: r'(?i)humedad'),
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'presion', columnPattern: r'(?i)presi.n|presion'),
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'observaciones', columnPattern: r'(?i)observa'),
      CsvFieldMapping(module: 'equipos', section: 'condiciones_ambientales', fieldKey: 'responsable', columnPattern: r'(?i)responsable'),
    ],
  ),
  CsvModuleDetector(
    moduleKey: 'equipos',
    moduleName: 'Campanas Flujo Laminar',
    sectionKey: 'campanas_flujo_laminar',
    minScore: 0.3,
    mappings: [
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'fecha', columnPattern: r'(?i)^fecha'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'nombre', columnPattern: r'(?i)nomb(re|re abreviado)'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'actividad', columnPattern: r'(?i)actividad'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'campana1', columnPattern: r'(?i)campana.*1'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'campana2', columnPattern: r'(?i)campana.*2'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'campana3', columnPattern: r'(?i)campana.*3'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'limpieza_previa', columnPattern: r'(?i)limpieza'),
      CsvFieldMapping(module: 'equipos', section: 'campanas_flujo_laminar', fieldKey: 'observaciones', columnPattern: r'(?i)observa'),
    ],
  ),
  CsvModuleDetector(
    moduleKey: 'equipos',
    moduleName: 'Centrifugadoras',
    sectionKey: 'centrifugadoras',
    minScore: 0.3,
    mappings: [
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'fecha', columnPattern: r'(?i)^fecha'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'nombre', columnPattern: r'(?i)nomb(re|re abreviado)'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'actividad', columnPattern: r'(?i)actividad'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'centrifugadora1', columnPattern: r'(?i)centrifuga.*1'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'centrifugadora2', columnPattern: r'(?i)centrifuga.*2'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'centrifugadora3', columnPattern: r'(?i)centrifuga.*3'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'limpieza_previa', columnPattern: r'(?i)limpieza'),
      CsvFieldMapping(module: 'equipos', section: 'centrifugadoras', fieldKey: 'observaciones', columnPattern: r'(?i)observa'),
    ],
  ),
  CsvModuleDetector(
    moduleKey: 'equipos',
    moduleName: 'Microscopio',
    sectionKey: 'microscopio',
    minScore: 0.3,
    mappings: [
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'fecha', columnPattern: r'(?i)^fecha'),
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'hora_inicio', columnPattern: r'(?i)hora.*inicio|hora ini'),
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'microscopio', columnPattern: r'(?i)microscopio'),
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'hora_fin', columnPattern: r'(?i)hora.*fin|hora fin'),
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'nombre', columnPattern: r'(?i)nomb(re|re abreviado)'),
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'actividad', columnPattern: r'(?i)actividad'),
      CsvFieldMapping(module: 'equipos', section: 'microscopio', fieldKey: 'observaciones', columnPattern: r'(?i)observa'),
    ],
  ),
  CsvModuleDetector(
    moduleKey: 'procesamiento',
    moduleName: 'Cajas y Exosomas',
    sectionKey: 'cajas_exosomas',
    minScore: 0.3,
    mappings: [
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'fecha', columnPattern: r'(?i)^columna 1|fecha'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'pedido', columnPattern: r'(?i)pedido'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'presentacion', columnPattern: r'(?i)presentacion'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'volumen', columnPattern: r'(?i)volumen'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'uso', columnPattern: r'(?i)^uso'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'tejido', columnPattern: r'(?i)tejido'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'paciente', columnPattern: r'(?i)paciente'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'enviado_a', columnPattern: r'(?i)enviado|enaviado'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'pedido_por', columnPattern: r'(?i)pedido por'),
      CsvFieldMapping(module: 'procesamiento', section: 'cajas_exosomas', fieldKey: 'notas', columnPattern: r'(?i)notas'),
    ],
  ),
];

double _matchScore(String column, String pattern) {
  try {
    final re = RegExp(pattern);
    return re.hasMatch(column) ? 1.0 : 0.0;
  } catch (_) {
    return 0.0;
  }
}

Map<String, CsvFieldMapping> detectModule(List<String> headers) {
  best(MapEntry<String, double> a, MapEntry<String, double> b) => a.value > b.value ? a : b;

  final scores = <String, double>{};
  final colMappings = <String, CsvFieldMapping>{};

  for (final detector in csvModuleDetectors) {
    double matchCount = 0;
    final localMappings = <String, CsvFieldMapping>{};

    for (final header in headers) {
      final trimmed = header.trim();
      double bestScore = 0;
      CsvFieldMapping? bestMapping;

      for (final mapping in detector.mappings) {
        final score = _matchScore(trimmed, mapping.columnPattern);
        if (score > bestScore) {
          bestScore = score;
          bestMapping = mapping;
        }
      }

      if (bestMapping != null && bestScore > 0) {
        localMappings[trimmed] = bestMapping;
        matchCount += bestScore;
      }
    }

    final ratio = headers.isEmpty ? 0.0 : matchCount / headers.length;
    scores['${detector.moduleKey}/${detector.sectionKey}'] = ratio;

    if (ratio >= detector.minScore && localMappings.length > colMappings.length) {
      colMappings.clear();
      colMappings.addAll(localMappings);
    }
  }

  return colMappings;
}

String? detectBestModule(List<String> headers) {
  if (headers.isEmpty) return null;

  double bestRatio = 0;
  String? bestKey;

  for (final detector in csvModuleDetectors) {
    double matchCount = 0;
    for (final header in headers) {
      final trimmed = header.trim();
      for (final mapping in detector.mappings) {
        if (_matchScore(trimmed, mapping.columnPattern) > 0) {
          matchCount++;
          break;
        }
      }
    }
    final ratio = matchCount / headers.length;
    if (ratio > bestRatio) {
      bestRatio = ratio;
      bestKey = '${detector.moduleKey}/${detector.sectionKey}';
    }
  }

  return bestRatio >= 0.3 ? bestKey : null;
}

List<String> parseCsvLine(String line) {
  final result = <String>[];
  bool inQuotes = false;
  final current = StringBuffer();

  for (int i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        current.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      result.add(current.toString().trim());
      current.clear();
    } else {
      current.write(ch);
    }
  }
  result.add(current.toString().trim());
  return result;
}
