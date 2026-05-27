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
  _misidModule(),
  _solucionCobreModule(),
  _muestrasModule(),
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
        {'key': 'cargo', 'label': 'Cargo', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Actividades Realizadas',
        'key': 'actividades',
        'columns': [
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'width': 200},
          {'key': 'descripcion', 'label': 'Descripcion de la Actividad', 'type': 'text', 'width': 350},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 350},
        ],
      },
      'cajas_table': {
        'label': 'Cajas Procesadas / Control Cultivo',
        'key': 'cajas_procesadas',
        'columns': [
          {'key': 'cajas', 'label': 'Cajas', 'type': 'text', 'width': 100},
          {'key': 'tipo_tejido', 'label': 'Tipo Tejido', 'type': 'select', 'options': ['Tejido Adiposo', 'Placenta', 'Membrana', 'Endometrio', 'Pulpa', 'GW', 'Autologas', 'Alogenicas'], 'width': 130},
          {'key': 'viales', 'label': 'Viales', 'type': 'text', 'width': 100},
          {'key': 'misid', 'label': 'MISID', 'type': 'select', 'options': ['MISID', 'MISID ADVANCE', 'NA'], 'width': 110},
          {'key': 'millones', 'label': 'Mill Cel', 'type': 'text', 'width': 90},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
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
      ],
      'activities_table': {
        'label': 'Lecturas de Temperatura y CO2',
        'key': 'lecturas',
        'columns': [
          {'key': 'equipo', 'label': 'Incubadora', 'type': 'select', 'dynamic': 'Incubadoras', 'width': 140},
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
      ],
      'activities_table': {
        'label': 'Ciclos de Esterilización',
        'key': 'ciclos',
        'columns': [
          {'key': 'ciclo_no', 'label': 'Ciclo No.', 'type': 'number', 'width': 70},
          {'key': 'equipo', 'label': 'Autoclave', 'type': 'select', 'dynamic': 'Autoclaves', 'width': 160},
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
          {'key': 'equipo', 'label': 'Autoclave', 'type': 'select', 'dynamic': 'Autoclaves', 'width': 120},
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
      ],
      'activities_table': {
        'label': 'Lecturas de Temperatura',
        'key': 'temperaturas',
        'columns': [
          {'key': 'equipo', 'label': 'Ultracongelador', 'type': 'select', 'dynamic': 'Ultracongeladores', 'width': 150},
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
          {'key': 'campana', 'label': 'Campana', 'type': 'select', 'dynamic': 'Campanas', 'width': 160},
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
          {'key': 'centrifuga', 'label': 'Centrífuga', 'type': 'select', 'dynamic': 'Centrifugas', 'width': 150},
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
          {'key': 'microscopio', 'label': 'Microscopio', 'type': 'select', 'dynamic': 'Microscopios', 'width': 160},
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
          {'key': 'equipo', 'label': 'Equipo', 'type': 'select', 'dynamic': 'Potenciometros', 'width': 150},
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

FormModuleDef _solucionCobreModule() => {
  'module': 'solucion_cobre',
  'label': 'Solucion de Iones Libres de Cobre',
  'icon': 'science',
  'color': '0xFF00BCD4',
  'sections': [
    {
      'key': 'preparacion',
      'label': 'Preparacion y Actividades del Dia',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Final', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Actividades Realizadas',
        'key': 'actividades',
        'columns': [
          {'key': 'descripcion', 'label': 'Descripcion de la Actividad', 'type': 'text', 'width': 350},
          {'key': 'resultados', 'label': 'Observaciones / Resultados', 'type': 'text', 'width': 350},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
      ],
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
      'key': 'cultivo_celular',
      'label': 'Cultivo Celular',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'cargo_operativo', 'label': 'Cargo', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Procesamiento / Control CA',
        'key': 'procesamiento_ca',
        'columns': [
          {'key': 'presentacion', 'label': 'Presentacion', 'type': 'select', 'options': ['100M', '50M', '30M', 'EXOSOMAS', '100M+EXO'], 'width': 100},
          {'key': 'volumen', 'label': 'Vol (CC)', 'type': 'select', 'options': ['5CC', '3CC', '2CC', '1CC', '10CC'], 'width': 80},
          {'key': 'uso', 'label': 'Uso Terapeutico', 'type': 'select', 'options': ['SISTEMICO', 'ARTICULAR RODILLA', 'ARTICULAR CADERA', 'ARTICULAR TOBILLO', 'ARTICULAR LUMBAR', 'INTRAVENOSO', 'TOPICO'], 'width': 120},
          {'key': 'tejido', 'label': 'Tipo Tejido', 'type': 'select', 'options': ['PLACENTA', 'TEJIDO ADIPOSO', 'PULPA', 'ENDOMETRIO', 'MEMBRANA', 'GW', 'AUTOLOGAS', 'ALOGENICAS', 'EXOSOMAS', 'CORDON UMBILICAL'], 'width': 120},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 150},
          {'key': 'tipo_envio', 'label': 'Tipo Envio', 'type': 'select', 'options': ['CELULAS', 'EXOSOMAS', 'MEDIO CONDICIONADO', 'FACTORES DE CRECIMIENTO', 'NA'], 'width': 120},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'select', 'options': ['INMUNOTERAPIA', 'QUANTUM', 'HOSPITAL', 'CLINICA PRIVADA', 'OTRO'], 'width': 120},
          {'key': 'pedido_por', 'label': 'Solicitado por', 'type': 'select', 'options': ['DR. JAVIER ARENAS', 'DRA. MARIA RIVERA', 'DR. CARLOS MENDOZA', 'ERICK', 'OTRO'], 'width': 120},
          {'key': 'fecha_proceso', 'label': 'Fecha Proceso', 'type': 'date', 'width': 100},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 180},
          {'key': 'continuacion', 'label': 'Continuacion', 'type': 'text', 'width': 170},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Firma Responsable', 'type': 'autofill'},
      ],
    },
    {
      'key': 'flask_cultivo',
      'label': 'Flask en Cultivo',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'cajas_table': {
        'label': 'Flask en Cultivo',
        'key': 'flask',
        'columns': [
          {'key': 'incubadora', 'label': 'Incubadora', 'type': 'select', 'dynamic': 'Incubadoras', 'width': 110},
          {'key': 'tipo_flask', 'label': 'Tipo Flask', 'type': 'select', 'options': ['T25', 'T75', 'T175', 'T300'], 'width': 80},
          {'key': 'tipo_celular', 'label': 'Tipo Celular', 'type': 'select', 'options': ['MSC', 'NK', 'FIBROBLASTOS', 'CONDROCITOS', 'ADIPOCITOS', 'IPSC', 'EXOSOMAS'], 'width': 110},
          {'key': 'pase', 'label': 'Pase', 'type': 'number', 'width': 60},
          {'key': 'cantidad', 'label': 'Cant', 'type': 'number', 'width': 60},
          {'key': 'confluencia', 'label': 'Conf %', 'type': 'number', 'width': 70},
          {'key': 'fecha_siembra', 'label': 'Siembra', 'type': 'date', 'width': 85},
          {'key': 'proximo_cambio', 'label': 'Prox Cambio', 'type': 'date', 'width': 85},
          {'key': 'medio', 'label': 'Medio', 'type': 'text', 'width': 120},
          {'key': 'observaciones', 'label': 'Obs', 'type': 'text', 'width': 160},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
      ],
    },
    {
      'key': 'misids',
      'label': 'MISID',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Procesamiento MISID',
        'key': 'procesamiento',
        'columns': [
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['MISID', 'MISID ADVANCE'], 'width': 130},
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'number', 'width': 90},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
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
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['1CC', '2CC', '3CC'], 'width': 80},
          {'key': 'tejido', 'label': 'Tipo', 'type': 'select', 'options': ['AUTOLOGAS', 'ALOGENICAS'], 'width': 100},
          {'key': 'conteo_final', 'label': 'Conteo Final', 'type': 'text', 'width': 100},
          {'key': 'viabilidad', 'label': 'Viabilidad %', 'type': 'number', 'width': 80},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [],
    },
    {
      'key': 'viales',
      'label': 'Viales / Criopreservacion',
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
          {'key': 'concentracion', 'label': 'Concentracion', 'type': 'text', 'width': 100},
          {'key': 'ubicacion', 'label': 'Ubicacion', 'type': 'select', 'options': ['TN-1', 'TN-2', 'TN-3', 'UC-1', 'UC-2'], 'width': 100},
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

FormModuleDef _muestrasModule() => {
  'module': 'muestras',
  'label': 'Muestras (EN DESARROLLO)',
  'icon': 'biotech',
  'color': '0xFFFF6B35',
  'dev': true,
  'sections': [
    {
      'key': 'registro_muestras',
      'label': 'Registro de Muestras',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'paciente', 'label': 'Paciente / Donante', 'type': 'text', 'width': 160},
        {'key': 'tipo_muestra', 'label': 'Tipo de Muestra', 'type': 'select', 'options': ['Sangre', 'Tejido', 'Plasma', 'Suero', 'Orina', 'Saliva', 'Liquido Sinovial', 'Liquido Cefalorraquideo', 'Biopsia', 'Otro'], 'width': 160},
        {'key': 'origen', 'label': 'Origen', 'type': 'select', 'options': ['Paciente', 'Donante', 'Externo', 'Banco'], 'width': 120},
      ],
      'activities_table': {
        'label': 'Procesamiento de Muestras',
        'key': 'procesamiento',
        'columns': [
          {'key': 'codigo', 'label': 'Codigo Muestra', 'type': 'text', 'width': 130},
          {'key': 'tipo_procesamiento', 'label': 'Procesamiento', 'type': 'select', 'options': ['Centrifugacion', 'Separacion Celular', 'Filtracion', 'Criopreservacion', 'Lisis', 'Extraccion ADN/ARN', 'Fijacion'], 'width': 140},
          {'key': 'volumen_inicial', 'label': 'Vol. Inicial', 'type': 'number', 'width': 80},
          {'key': 'volumen_final', 'label': 'Vol. Final', 'type': 'number', 'width': 80},
          {'key': 'ubicacion', 'label': 'Ubicacion', 'type': 'text', 'width': 120},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
  ],
};

FormModuleDef _misidModule() => {
  'module': 'misid',
  'label': 'Procesamiento MISID',
  'icon': 'science',
  'color': '0xFF4CAF50',
  'sections': [
    {
      'key': 'misids',
      'label': 'MISID',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Procesamiento MISID',
        'key': 'procesamiento',
        'columns': [
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['MISID', 'MISID ADVANCE'], 'width': 130},
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'number', 'width': 90},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [],
    },
  ],
};
