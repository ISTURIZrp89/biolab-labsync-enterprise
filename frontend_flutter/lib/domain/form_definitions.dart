typedef FormFieldDef = Map<String, dynamic>;
typedef FormSectionDef = Map<String, dynamic>;
typedef FormModuleDef = Map<String, dynamic>;

FormModuleDef findModule(String module) {
  return formModules.firstWhere(
    (m) => m['module'] == module,
    orElse: () => <String, dynamic>{},
  );
}

FormSectionDef? findSection(String module, String sectionKey) {
  final mod = findModule(module);
  if (mod.isEmpty) return null;
  final sections = mod['sections'] as List? ?? [];
  for (var s in sections) {
    if (s['key'] == sectionKey) return s;
  }
  return null;
}

final List<FormModuleDef> formModules = [
  _bitacoraModule(),
  _incubadorasModule(),
  _autoclavesModule(),
  _ultracongeladoresModule(),
  _equiposModule(),
  _procesamientoModule(),
];

FormModuleDef _bitacoraModule() => {
  'module': 'bitacora',
  'label': 'Bitácora General',
  'icon': 'book',
  'color': '0xFFE91E63',
  'sections': [
    {
      'key': 'actividades',
      'label': 'Actividades del Día',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Final', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Elaborado por', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
        {'key': 'area', 'label': 'Área', 'type': 'autofill'},
        {'key': 'turno', 'label': 'Turno', 'type': 'autofill'},
        {'key': 'supervisor', 'label': 'Supervisor', 'type': 'autofill'},
        {'key': 'firma_responsable', 'label': 'Firma Responsable', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Actividades Realizadas',
        'key': 'actividades',
        'columns': [
          {'key': 'hora', 'label': 'Hora', 'type': 'time', 'width': 80},
          {'key': 'descripcion', 'label': 'Descripción de la Actividad', 'type': 'text', 'width': 250},
          {'key': 'resultados', 'label': 'Observaciones / Resultados', 'type': 'text', 'width': 250},
          {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'width': 180},
        ],
      },
      'resources_table': {
        'label': 'Recursos Utilizados',
        'key': 'recursos',
        'columns': [
          {'key': 'reactivo', 'label': 'Reactivo / Material', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Fecha Caducidad', 'type': 'date', 'width': 120},
          {'key': 'cantidad', 'label': 'Cantidad', 'type': 'number', 'width': 80},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias Generales', 'type': 'text', 'multiline': true},
        {'key': 'acuerdos', 'label': 'Acuerdos / Pendientes', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Vo.Bo. Supervisor', 'type': 'autofill'},
      ],
    },
  ],
};

FormModuleDef _incubadorasModule() => {
  'module': 'incubadoras',
  'label': 'Incubadoras',
  'icon': 'thermostat',
  'color': '0xFFFF6B6B',
  'sections': [
    {
      'key': 'registro',
      'label': 'Registro Diario de Incubadoras',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora', 'label': 'Hora de Lectura', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
        {'key': 'area', 'label': 'Área', 'type': 'autofill'},
        {'key': 'supervisor', 'label': 'Supervisor', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Lecturas de Temperatura y CO2',
        'key': 'lecturas',
        'columns': [
          {'key': 'equipo', 'label': 'Incubadora', 'type': 'select', 'options': ['SANYO MCO-18AIC', 'HERACELL VIOS 160i', 'STERI-CULT 200', 'FORMA 3110', 'NUAIRE NU-8700'], 'width': 140},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 100},
          {'key': 'temp_min', 'label': 'Temp Min', 'type': 'number', 'width': 80},
          {'key': 'temp_max', 'label': 'Temp Max', 'type': 'number', 'width': 80},
          {'key': 'co2', 'label': 'CO2 %', 'type': 'number', 'width': 80},
          {'key': 'co2_min', 'label': 'CO2 Min', 'type': 'number', 'width': 80},
          {'key': 'co2_max', 'label': 'CO2 Max', 'type': 'number', 'width': 80},
          {'key': 'humedad', 'label': 'Humedad %', 'type': 'number', 'width': 80},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['OK', 'NA', 'ALARMA', 'MANTENIMIENTO'], 'width': 110},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'resources_table': {
        'label': 'Calibraciones / Mantenimiento',
        'key': 'mantenimiento',
        'columns': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'width': 100},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'width': 200},
          {'key': 'realizado_por', 'label': 'Realizado por', 'type': 'text', 'width': 150},
          {'key': 'resultado', 'label': 'Resultado', 'type': 'select', 'options': ['OK', 'OBSERVACION', 'PENDIENTE'], 'width': 100},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias / Alarmas', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Firma Responsable', 'type': 'autofill'},
      ],
    },
  ],
};

FormModuleDef _autoclavesModule() => {
  'module': 'autoclaves',
  'label': 'Autoclaves',
  'icon': 'local_fire_department',
  'color': '0xFFFFA94D',
  'sections': [
    {
      'key': 'ciclos',
      'label': 'Ciclos del Día',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
        {'key': 'area', 'label': 'Área', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Ciclos de Esterilización',
        'key': 'ciclos',
        'columns': [
          {'key': 'ciclo_no', 'label': 'Ciclo No.', 'type': 'number', 'width': 70},
          {'key': 'equipo', 'label': 'Autoclave', 'type': 'select', 'options': ['AUTOCLAVE 1 - TUTTNAUER', 'AUTOCLAVE 2 - STERIS', 'AUTOCLAVE 3 - GETINGE'], 'width': 160},
          {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'width': 90},
          {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time', 'width': 90},
          {'key': 'contenido', 'label': 'Contenido / Carga', 'type': 'text', 'width': 180},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 90},
          {'key': 'tiempo', 'label': 'Tiempo (min)', 'type': 'number', 'width': 90},
          {'key': 'presion', 'label': 'Presión (psi)', 'type': 'number', 'width': 90},
          {'key': 'resultado', 'label': 'Resultado', 'type': 'select', 'options': ['OK', 'FALLO', 'REPROCESO', 'CANCELADO'], 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Vo.Bo.', 'type': 'autofill'},
      ],
    },
    {
      'key': 'mantenimiento',
      'label': 'Mantenimiento',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Actividades de Mantenimiento',
        'key': 'actividades',
        'columns': [
          {'key': 'equipo', 'label': 'Autoclave', 'type': 'select', 'options': ['AUTOCLAVE 1', 'AUTOCLAVE 2', 'AUTOCLAVE 3'], 'width': 120},
          {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text', 'width': 250},
          {'key': 'realizado_por', 'label': 'Realizado por', 'type': 'text', 'width': 150},
          {'key': 'fecha_prox', 'label': 'Próximo Mantenimiento', 'type': 'date', 'width': 120},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'testigos',
      'label': 'Control de Testigos',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Testigos de Esterilización',
        'key': 'testigos',
        'columns': [
          {'key': 'ciclo', 'label': 'Ciclo', 'type': 'number', 'width': 60},
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['BIOLÓGICO', 'QUÍMICO', 'FÍSICO'], 'width': 110},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 110},
          {'key': 'caducidad', 'label': 'Caducidad', 'type': 'date', 'width': 100},
          {'key': 'resultado', 'label': 'Resultado', 'type': 'select', 'options': ['PASA', 'FALLA'], 'width': 90},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
  ],
};

FormModuleDef _ultracongeladoresModule() => {
  'module': 'ultracongeladores',
  'label': 'Ultracongeladores',
  'icon': 'ac_unit',
  'color': '0xFF3B82F6',
  'sections': [
    {
      'key': 'registro',
      'label': 'Registro Diario de Temperatura',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora', 'label': 'Hora de Lectura', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
        {'key': 'area', 'label': 'Área', 'type': 'autofill'},
        {'key': 'supervisor', 'label': 'Supervisor', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Lecturas de Temperatura',
        'key': 'temperaturas',
        'columns': [
          {'key': 'equipo', 'label': 'Ultracongelador', 'type': 'select', 'options': ['UC-1 (-80°C)', 'UC-2 (-80°C)', 'UC-3 (-20°C)', 'UC-4 (-80°C)', 'UC-5 (-150°C)'], 'width': 150},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 100},
          {'key': 'temp_min', 'label': 'Temp Mínima', 'type': 'number', 'width': 90},
          {'key': 'temp_max', 'label': 'Temp Máxima', 'type': 'number', 'width': 90},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['OK', 'ALARMA', 'DESCONECTADO', 'MANTENIMIENTO'], 'width': 120},
          {'key': 'nivel_co2', 'label': 'CO2 Backup', 'type': 'select', 'options': ['OK', 'BAJO', 'VACÍO', 'NA'], 'width': 100},
          {'key': 'alarma_activa', 'label': 'Alarma', 'type': 'select', 'options': ['NO', 'SÍ - TEMP', 'SÍ - PUERTA', 'SÍ - BATERÍA'], 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'resources_table': {
        'label': 'Mantenimiento / Alertas',
        'key': 'alertas',
        'columns': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'width': 100},
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['ALERTA', 'MANTENIMIENTO', 'CALIBRACIÓN', 'LIMPIEZA'], 'width': 120},
          {'key': 'descripcion', 'label': 'Descripción', 'type': 'text', 'width': 250},
          {'key': 'atendido_por', 'label': 'Atendido por', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias / Alarmas', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Firma Responsable', 'type': 'autofill'},
      ],
    },
  ],
};

FormModuleDef _equiposModule() => {
  'module': 'equipos',
  'label': 'Equipos',
  'icon': 'precision_manufacturing',
  'color': '0xFF69DB7C',
  'sections': [
    {
      'key': 'condiciones_ambientales',
      'label': 'Condiciones Ambientales',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora', 'label': 'Hora de Lectura', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'area', 'label': 'Área', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Lecturas Ambientales',
        'key': 'lecturas',
        'columns': [
          {'key': 'area', 'label': 'Área / Laboratorio', 'type': 'select', 'options': ['LAB-1 CULTIVO', 'LAB-2 PROCESAMIENTO', 'LAB-3 CONTROL', 'ALMACÉN', 'CUARTO FRÍO'], 'width': 140},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 100},
          {'key': 'humedad', 'label': 'Humedad %', 'type': 'number', 'width': 90},
          {'key': 'presion', 'label': 'Presión (Pa)', 'type': 'number', 'width': 90},
          {'key': 'particulas', 'label': 'Partículas', 'type': 'number', 'width': 90},
          {'key': 'iluminacion', 'label': 'Iluminación (Lux)', 'type': 'number', 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'campanas_flujo_laminar',
      'label': 'Campanas Flujo Laminar',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Registro Diario',
        'key': 'registro',
        'columns': [
          {'key': 'campana', 'label': 'Campana', 'type': 'select', 'options': ['CABINA 1 - BIOSAFETY II', 'CABINA 2 - BIOSAFETY II', 'CABINA 3 - LAMINAR FLOW', 'CABINA 4 - PCR'], 'width': 160},
          {'key': 'hora_encendido', 'label': 'Encendido', 'type': 'time', 'width': 80},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ENCENDIDA', 'APAGADA', 'MANTENIMIENTO'], 'width': 110},
          {'key': 'limpieza', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SÍ', 'NO', 'NA'], 'width': 100},
          {'key': 'uv_previo', 'label': 'UV Previo (min)', 'type': 'number', 'width': 90},
          {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text', 'width': 250},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'centrifugadoras',
      'label': 'Centrifugadoras',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Registro de Uso',
        'key': 'registro',
        'columns': [
          {'key': 'centrifuga', 'label': 'Centrífuga', 'type': 'select', 'options': ['CENTRI-1 SORVALL', 'CENTRI-2 EPPENDORF', 'CENTRI-3 BECKMAN', 'MICROCENTRI-1', 'MICROCENTRI-2'], 'width': 150},
          {'key': 'hora_inicio', 'label': 'Inicio', 'type': 'time', 'width': 80},
          {'key': 'hora_fin', 'label': 'Fin', 'type': 'time', 'width': 80},
          {'key': 'rpm', 'label': 'RPM', 'type': 'number', 'width': 90},
          {'key': 'tiempo', 'label': 'Tiempo (min)', 'type': 'number', 'width': 90},
          {'key': 'temperatura', 'label': 'Temp °C', 'type': 'number', 'width': 80},
          {'key': 'rotor', 'label': 'Rotor', 'type': 'text', 'width': 100},
          {'key': 'actividad', 'label': 'Uso / Muestra', 'type': 'text', 'width': 200},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'microscopio',
      'label': 'Microscopios',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time'},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Registro de Uso',
        'key': 'usos',
        'columns': [
          {'key': 'microscopio', 'label': 'Microscopio', 'type': 'select', 'options': ['1 - INVERTIDO LEICA', '2 - COMPUESTO ZEISS', '3 - ESTEREOSCOPIO NIKON', '4 - CONFOCAL', '5 - FLUORESCENCIA'], 'width': 160},
          {'key': 'objetivo', 'label': 'Objetivo', 'type': 'text', 'width': 100},
          {'key': 'actividad', 'label': 'Actividad / Muestra', 'type': 'text', 'width': 250},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
      ],
    },
    {
      'key': 'potenciometro',
      'label': 'Potenciómetros / pH',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time'},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Mediciones',
        'key': 'mediciones',
        'columns': [
          {'key': 'equipo', 'label': 'Equipo', 'type': 'select', 'options': ['pHmetro 1 - HANNA', 'pHmetro 2 - METTLER', 'CONDUCTIMETRO', 'SPECTROPHOTOMETER'], 'width': 150},
          {'key': 'ph_obtenido', 'label': 'pH Obtenido', 'type': 'text', 'width': 100},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 90},
          {'key': 'calibracion', 'label': 'Calibración', 'type': 'select', 'options': ['SÍ', 'NO', 'PENDIENTE'], 'width': 100},
          {'key': 'solucion', 'label': 'Solución Std', 'type': 'text', 'width': 100},
          {'key': 'actividad', 'label': 'Actividad / Muestra', 'type': 'text', 'width': 250},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
  ],
};

FormModuleDef _procesamientoModule() => {
  'module': 'procesamiento',
  'label': 'Procesamiento',
  'icon': 'biotech',
  'color': '0xFFB197FC',
  'sections': [
    {
      'key': 'cajas_exosomas',
      'label': 'Cajas y Exosomas',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
        {'key': 'area', 'label': 'Área', 'type': 'autofill'},
        {'key': 'supervisor', 'label': 'Supervisor', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Procesamiento',
        'key': 'procesamiento',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido No.', 'type': 'number', 'width': 70},
          {'key': 'presentacion', 'label': 'Presentación', 'type': 'select', 'options': ['100M', '50M', '30M', 'EXOSOMAS', '100M+EXO'], 'width': 110},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['5CC', '3CC', '2CC', '1CC', '10CC'], 'width': 80},
          {'key': 'uso', 'label': 'Uso Terapéutico', 'type': 'select', 'options': ['SISTÉMICO', 'ARTICULAR RODILLA', 'ARTICULAR CADERA', 'INTRAVENOSO', 'TÓPICO'], 'width': 140},
          {'key': 'tejido', 'label': 'Tipo de Tejido', 'type': 'select', 'options': ['PLACENTA', 'TEJIDO ADIPOSO', 'AUTÓLOGAS', 'ALOGÉNICAS', 'ENDOMETRIO', 'CORDÓN UMBILICAL'], 'width': 130},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 140},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'select', 'options': ['INMUNOTERAPIA', 'QUANTUM', 'HOSPITAL', 'CLÍNICA PRIVADA', 'OTRO'], 'width': 120},
          {'key': 'pedido_por', 'label': 'Solicitado por', 'type': 'select', 'options': ['DR. JAVIER ARENAS', 'DRA. MARÍA RIVERA', 'DR. CARLOS MENDOZA', 'OTRO'], 'width': 130},
          {'key': 'fecha_proceso', 'label': 'Fecha Proceso', 'type': 'date', 'width': 100},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'resources_table': {
        'label': 'Reactivos y Materiales',
        'key': 'recursos',
        'columns': [
          {'key': 'reactivo', 'label': 'Reactivo / Material', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote No.', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Fecha Caducidad', 'type': 'date', 'width': 120},
          {'key': 'cantidad', 'label': 'Cantidad', 'type': 'number', 'width': 80},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Firma Responsable', 'type': 'autofill'},
      ],
    },
    {
      'key': 'cultivo_celular',
      'label': 'Cultivo Celular',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Actividades de Cultivo',
        'key': 'cultivos',
        'columns': [
          {'key': 'tipo_celular', 'label': 'Tipo Celular', 'type': 'select', 'options': ['MSC', 'NK', 'FIBROBLASTOS', 'CONDROCITOS', 'ADIPOCITOS', 'IPSC'], 'width': 130},
          {'key': 'pase', 'label': 'Pase No.', 'type': 'number', 'width': 70},
          {'key': 'conteo', 'label': 'Conteo (células/ml)', 'type': 'text', 'width': 110},
          {'key': 'viabilidad', 'label': 'Viabilidad %', 'type': 'number', 'width': 90},
          {'key': 'frascos', 'label': 'Frascos Sembrados', 'type': 'number', 'width': 100},
          {'key': 'medio', 'label': 'Medio Utilizado', 'type': 'text', 'width': 150},
          {'key': 'suplemento', 'label': 'Suplemento', 'type': 'text', 'width': 130},
          {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'width': 200},
        ],
      },
      'resources_table': {
        'label': 'Medios y Reactivos',
        'key': 'medios',
        'columns': [
          {'key': 'producto', 'label': 'Producto', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Caducidad', 'type': 'date', 'width': 120},
          {'key': 'volumen_usado', 'label': 'Vol. Usado (ml)', 'type': 'number', 'width': 100},
        ],
      },
      'fields': [],
    },
    {
      'key': 'misids',
      'label': 'MISIDs',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Procesamiento MISID',
        'key': 'procesamiento',
        'columns': [
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'number', 'width': 90},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['MISID ADVANCE', 'TRATAMIENTO DAÑO ADN', 'FERTILIDAD'], 'width': 160},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'pedido_por', 'label': 'Solicitado por', 'type': 'text', 'width': 130},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'resources_table': {
        'label': 'Reactivos',
        'key': 'reactivos',
        'columns': [
          {'key': 'reactivo', 'label': 'Reactivo', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Caducidad', 'type': 'date', 'width': 120},
        ],
      },
      'fields': [],
    },
    {
      'key': 'nk',
      'label': 'NK (Natural Killers)',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Procesamiento NK',
        'key': 'procesamiento',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido No.', 'type': 'number', 'width': 70},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['1CC', '2CC', '3CC'], 'width': 80},
          {'key': 'tejido', 'label': 'Tipo', 'type': 'select', 'options': ['AUTÓLOGAS', 'ALOGÉNICAS'], 'width': 100},
          {'key': 'conteo_final', 'label': 'Conteo Final', 'type': 'text', 'width': 100},
          {'key': 'viabilidad', 'label': 'Viabilidad %', 'type': 'number', 'width': 80},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'pedido_por', 'label': 'Solicitado por', 'type': 'text', 'width': 130},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [],
    },
    {
      'key': 'viales',
      'label': 'Viales / Criopreservación',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Registro de Viales',
        'key': 'viales',
        'columns': [
          {'key': 'vial_id', 'label': 'ID Vial', 'type': 'text', 'width': 120},
          {'key': 'tipo_celula', 'label': 'Tipo Celular', 'type': 'select', 'options': ['MSC', 'NK', 'EXOSOMAS', 'FIBROBLASTOS', 'PLASMA'], 'width': 120},
          {'key': 'paciente', 'label': 'Paciente / Donante', 'type': 'text', 'width': 130},
          {'key': 'cantidad', 'label': 'Cantidad', 'type': 'number', 'width': 80},
          {'key': 'concentracion', 'label': 'Concentración', 'type': 'text', 'width': 100},
          {'key': 'ubicacion', 'label': 'Ubicación', 'type': 'select', 'options': ['TN-1', 'TN-2', 'TN-3', 'UC-1', 'UC-2'], 'width': 100},
          {'key': 'fecha_criop', 'label': 'Fecha Criop.', 'type': 'date', 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'otros_productos',
      'label': 'Otros Productos',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Productos Terminados',
        'key': 'productos',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido No.', 'type': 'number', 'width': 70},
          {'key': 'producto', 'label': 'Producto', 'type': 'text', 'width': 180},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'text', 'width': 80},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [],
    },
  ],
};
