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
  _solucionCobreModule(),
];

FormModuleDef _bitacoraModule() => {
  'module': 'bitacora',
  'label': 'Bitacora General',
  'icon': 'book',
  'color': '0xFFE91E63',
  'sections': [
    {
      'key': 'actividades',
      'label': 'Actividades del Dia',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Final', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Elaborado por', 'type': 'autofill', 'required': true},
        {'key': 'cargo', 'label': 'Cargo', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Actividades',
        'key': 'actividades',
        'columns': [
          {'key': 'descripcion', 'label': 'Descripcion de la Actividad', 'type': 'text', 'width': 350},
          {'key': 'resultados', 'label': 'Observaciones / Resultados', 'type': 'text', 'width': 350},
        ],
      },
      'cajas_table': {
        'label': 'Cajas Procesadas',
        'key': 'cajas_procesadas',
        'columns': [
          {'key': 'cajas', 'label': 'Cajas Procesadas', 'type': 'text', 'width': 150},
          {'key': 'tipo_tejido', 'label': 'Tipo de Tejido', 'type': 'select', 'options': ['Tejido Adiposo', 'Placenta', 'Membrana', 'Endometrio', 'Pulpa', 'GW', 'Autologas', 'Alogenicas'], 'width': 150},
          {'key': 'viales', 'label': 'Viales Solicitados', 'type': 'text', 'width': 200},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 250},
        ],
      },
      'resources_table': {
        'label': 'Recursos Utilizados',
        'key': 'recursos',
        'columns': [
          {'key': 'reactivo', 'label': 'Reactivo', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Fecha Caducidad', 'type': 'date', 'width': 120},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
        {'key': 'firma_responsable', 'label': 'Firma Responsable', 'type': 'autofill'},
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
      'label': 'Registro Diario',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora', 'label': 'Hora', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Lecturas',
        'key': 'lecturas',
        'columns': [
          {'key': 'equipo', 'label': 'Equipo', 'type': 'select', 'options': ['SANYO', 'HERACELL', 'STERI-CULT'], 'width': 120},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 100},
          {'key': 'co2', 'label': 'CO2 %', 'type': 'number', 'width': 80},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ok', 'NA', 'ALARMA'], 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
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
      'label': 'Ciclos del Dia',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Ciclos',
        'key': 'ciclos',
        'columns': [
          {'key': 'ciclo_no', 'label': 'Ciclo No.', 'type': 'number', 'width': 80},
          {'key': 'equipo', 'label': 'Autoclave', 'type': 'select', 'options': ['AUTOCLAVE 1', 'AUTOCLAVE 2'], 'width': 120},
          {'key': 'contenido', 'label': 'Contenido', 'type': 'text', 'width': 200},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 100},
          {'key': 'tiempo', 'label': 'Tiempo (min)', 'type': 'number', 'width': 90},
          {'key': 'presion', 'label': 'Presion (psi)', 'type': 'number', 'width': 90},
          {'key': 'resultado', 'label': 'Resultado', 'type': 'select', 'options': ['OK', 'FALLO', 'REPROCESO'], 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
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
          {'key': 'equipo', 'label': 'Equipo', 'type': 'select', 'options': ['AUTOCLAVE 1', 'AUTOCLAVE 2'], 'width': 120},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'width': 250},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'testigos',
      'label': 'Testigos',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Testigos',
        'key': 'testigos',
        'columns': [
          {'key': 'ciclo', 'label': 'Ciclo', 'type': 'number', 'width': 70},
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['BIOLOGICO', 'QUIMICO', 'FISICO'], 'width': 110},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120},
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
      'label': 'Registro Diario',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora', 'label': 'Hora', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Temperaturas',
        'key': 'temperaturas',
        'columns': [
          {'key': 'equipo', 'label': 'Ultracongelador', 'type': 'select', 'options': ['UC-1 (-80)', 'UC-2 (-80)', 'UC-3 (-20)'], 'width': 140},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 110},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ok', 'ALARMA', 'DESCONECTADO'], 'width': 110},
          {'key': 'nivel_co2', 'label': 'CO2 Backup', 'type': 'select', 'options': ['OK', 'BAJO', 'VACIO'], 'width': 110},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
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
        {'key': 'hora', 'label': 'Hora', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Lecturas',
        'key': 'lecturas',
        'columns': [
          {'key': 'area', 'label': 'Area', 'type': 'select', 'options': ['LAB-1', 'LAB-2', 'LAB-3', 'ALMACEN'], 'width': 100},
          {'key': 'temperatura', 'label': 'Temperatura °C', 'type': 'number', 'width': 100},
          {'key': 'humedad', 'label': 'Humedad %', 'type': 'number', 'width': 90},
          {'key': 'presion', 'label': 'Presion', 'type': 'number', 'width': 90},
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
        'label': 'Registro',
        'key': 'registro',
        'columns': [
          {'key': 'campana', 'label': 'Campana', 'type': 'select', 'options': ['CAMPANA 1', 'CAMPANA 2', 'CAMPANA 3'], 'width': 120},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'width': 120},
          {'key': 'limpieza', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SI', 'NO'], 'width': 110},
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
        'label': 'Registro',
        'key': 'registro',
        'columns': [
          {'key': 'centrifuga', 'label': 'Centrifuga', 'type': 'select', 'options': ['CENTRI-1', 'CENTRI-2', 'CENTRI-3'], 'width': 120},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'width': 120},
          {'key': 'limpieza', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SI', 'NO'], 'width': 110},
          {'key': 'actividad', 'label': 'Uso', 'type': 'text', 'width': 200},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'microscopio',
      'label': 'Microscopio',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time'},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Usos',
        'key': 'usos',
        'columns': [
          {'key': 'microscopio', 'label': 'Microscopio', 'type': 'select', 'options': ['1 INVERTIDO', '2 COMPUESTO', '3 ESTEREOSCOPIO'], 'width': 140},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'width': 250},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'potenciometro',
      'label': 'Potenciometro',
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
          {'key': 'ph_obtenido', 'label': 'pH Obtenido', 'type': 'text', 'width': 120},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'width': 250},
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
      'key': 'cajas_exosomas',
      'label': 'Cajas y Exosomas',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Procesamiento',
        'key': 'procesamiento',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 70},
          {'key': 'presentacion', 'label': 'Presentacion', 'type': 'select', 'options': ['100M', '50M', '30M', 'EXOSOMAS'], 'width': 110},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['5CC', '3CC', '2CC', '1CC'], 'width': 80},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['SISTEMICO', 'ARTICULAR RODILLA', 'ARTICULAR CADERA'], 'width': 130},
          {'key': 'tejido', 'label': 'Tejido', 'type': 'select', 'options': ['PLACENTA', 'TEJIDO ADIPOSO', 'Autologas', 'ENDOMETRIO'], 'width': 110},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'QUANTUM'], 'width': 110},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'select', 'options': ['DR. JAVIER ARENAS'], 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'resources_table': {
        'label': 'Recursos Utilizados',
        'key': 'recursos',
        'columns': [
          {'key': 'reactivo', 'label': 'Reactivo', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Fecha Caducidad', 'type': 'date', 'width': 120},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
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
        'label': 'Procesamiento',
        'key': 'procesamiento',
        'columns': [
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'number', 'width': 90},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['MISID ADVANCE', 'TRATAMIENTO AL DAÑO DEL ADN'], 'width': 160},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [],
    },
    {
      'key': 'nk',
      'label': 'NK',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Procesamiento',
        'key': 'procesamiento',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 70},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['1CC'], 'width': 80},
          {'key': 'tejido', 'label': 'Tejido', 'type': 'select', 'options': ['Autologas', 'Alogenicas'], 'width': 100},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
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
        'label': 'Productos',
        'key': 'productos',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 70},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'text', 'width': 80},
          {'key': 'producto', 'label': 'Producto', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
      },
      'fields': [],
    },
  ],
};
