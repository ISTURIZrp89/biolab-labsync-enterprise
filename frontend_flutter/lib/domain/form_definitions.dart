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

const _responsables = ['Ana Altamirano', 'Oscar Duarte', 'Victor Rosas', 'Malu Ramirez', 'Adrian Cruz', 'Bernardo de Santiago', 'Alberto Parra'];
const _medicos = ['DR. PADILLA', 'DRA. ALEJANDRA ROJAS', 'DR. JAVIER ARENAS', 'DRA. ANDREA SALAS', 'DR. MANUEL ROSAS', 'DR. LUIS PADILLA', 'ERICK', 'OTRO'];

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
        {'key': 'hora_inicio', 'label': 'Hora de Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_final', 'label': 'Hora Final', 'type': 'time', 'required': true},
        {'key': 'elaborado_por', 'label': 'Elaborado por', 'type': 'autofill', 'required': true},
        {'key': 'cargo', 'label': 'Cargo', 'type': 'select', 'options': ['RESPONSABLE', 'INTEGRANTE', 'TÉCNICO']},
      ],
      'activities_table': {
        'label': 'Actividades Realizadas',
        'key': 'actividades',
        'columns': [
          {'key': 'actividad', 'label': 'Actividad', 'type': 'select', 'options': ['Envío de requisición', 'Cambio de medio', 'Expansión de cajas', 'Revisión de cajas de cultivo', 'Procesamiento', 'Limpieza', 'Mantenimiento'], 'width': 200},
          {'key': 'descripcion', 'label': 'Descripción de la Actividad', 'type': 'text', 'width': 350},
          {'key': 'observaciones', 'label': 'Observaciones / Resultados', 'type': 'text', 'width': 350},
        ],
      },
      'cajas_table': {
        'label': 'Cajas Procesadas y Producción',
        'key': 'cajas_procesadas',
        'columns': [
          {'key': 'cajas', 'label': 'Cajas Procesadas', 'type': 'number', 'width': 100},
          {'key': 'tipo_tejido', 'label': 'Tipo de Tejido', 'type': 'select', 'options': ['TA', 'PL', 'MEMBRANA', 'ENDOMETRIO', 'PULPA', 'GW', 'AUTOLOGAS', 'ALOGENICAS'], 'width': 130},
          {'key': 'viales', 'label': 'Viales Solicitados', 'type': 'number', 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'resources_table': {
        'label': 'Recursos e Insumos Utilizados (Trazabilidad)',
        'key': 'recursos',
        'columns': [
          {'key': 'reactivo', 'label': 'Reactivo / Material', 'type': 'text', 'width': 180, 'history': true},
          {'key': 'lote', 'label': 'Lote', 'type': 'text', 'width': 120, 'history': true},
          {'key': 'caducidad', 'label': 'Fecha de Caducidad', 'type': 'date', 'width': 120},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [
        {'key': 'conformidad', 'label': 'Conformidad / Vo.Bo.', 'type': 'text', 'multiline': true},
        {'key': 'firma', 'label': 'Firma Supervisor', 'type': 'autofill'},
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
      'key': 'lecturas',
      'label': 'Registro Diario de Incubadoras',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'modelo', 'label': 'Modelo del Equipo', 'type': 'select', 'options': ['SANYO', 'HERACELL', 'STERI-CULT'], 'required': true},
        {'key': 'usuario', 'label': 'Usuario', 'type': 'autofill', 'required': true},
        {'key': 'hora_inicial', 'label': 'Hora Inicial', 'type': 'time', 'required': true},
        {'key': 'temperatura_inicial', 'label': 'Temperatura °C Inicial', 'type': 'number', 'required': true},
        {'key': 'co2_inicial', 'label': '% CO2 Inicial', 'type': 'number', 'required': true},
        {'key': 'humedad_inicial', 'label': '% Humedad / Nivel Agua Inicial', 'type': 'select', 'options': ['OK', 'OPTIMO', 'FALTA', 'N/A']},
        {'key': 'hora_final', 'label': 'Hora Final', 'type': 'time', 'required': true},
        {'key': 'temperatura_final', 'label': 'Temperatura °C Final', 'type': 'number', 'required': true},
        {'key': 'co2_final', 'label': '% CO2 Final', 'type': 'number'},
        {'key': 'humedad_final', 'label': '% Humedad / Nivel Agua Final', 'type': 'select', 'options': ['OK', 'OPTIMO', 'FALTA', 'N/A']},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
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
      'label': 'Ciclos de Esterilización',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'operador', 'label': 'Operador', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Ciclos Realizados',
        'key': 'ciclos',
        'columns': [
          {'key': 'ciclo_no', 'label': 'Ciclo No.', 'type': 'number', 'width': 70},
          {'key': 'contenido', 'label': 'Contenido de la Carga', 'type': 'text', 'width': 300},
          {'key': 'temperatura', 'label': 'Temp. (°C)', 'type': 'number', 'width': 80},
          {'key': 'presion', 'label': 'Presión (kg/cm²)', 'type': 'number', 'width': 100},
          {'key': 'tiempo', 'label': 'Tiempo de Esteril.', 'type': 'select', 'options': ['15 minutos', '30 minutos', '45 minutos', '60 minutos'], 'width': 120},
          {'key': 'indicador', 'label': 'Indicador Químico (Viraje)', 'type': 'select', 'options': ['Correcto', 'Incorrecto'], 'width': 140},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 250},
        ],
      },
      'fields': [],
    },
    {
      'key': 'mantenimiento',
      'label': 'Mantenimiento',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha Servicio', 'type': 'date', 'required': true},
        {'key': 'tecnico', 'label': 'Técnico / Empresa', 'type': 'text'},
        {'key': 'tipo_servicio', 'label': 'Tipo de Servicio', 'type': 'select', 'options': ['Preventivo', 'Correctivo']},
        {'key': 'proxima_revision', 'label': 'Próxima Revisión', 'type': 'date'},
      ],
      'activities_table': {
        'label': 'Detalle de Mantenimiento',
        'key': 'detalle',
        'columns': [
          {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text', 'width': 300},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 300},
        ],
      },
      'fields': [],
    },
    {
      'key': 'testigos',
      'label': 'Testigos Biológicos',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha de Prueba', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Control de Testigos',
        'key': 'testigos',
        'columns': [
          {'key': 'tipo', 'label': 'Tipo de Indicador', 'type': 'text', 'width': 150},
          {'key': 'lote', 'label': 'Lote / Caducidad', 'type': 'text', 'width': 150},
          {'key': 'resultado', 'label': 'Resultado', 'type': 'select', 'options': ['Negativo', 'Positivo'], 'width': 100},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'width': 250},
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
      'label': 'Registro de Temperatura -80°C',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'modelo', 'label': 'Modelo', 'type': 'select', 'options': ['HAIER 100L', 'HAIER PB', 'THERMOFISHER'], 'required': true},
        {'key': 'usuario', 'label': 'Usuario / Responsable', 'type': 'autofill', 'required': true},
        {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ACTIVO', 'INACTIVO']},
        {'key': 'hora_inicio', 'label': 'Hora de Inicio', 'type': 'time', 'required': true},
        {'key': 'temp_inicial', 'label': 'Temperatura Inicial (°C)', 'type': 'text', 'required': true},
        {'key': 'hora_final', 'label': 'Hora de Término', 'type': 'time'},
        {'key': 'temp_final', 'label': 'Temperatura Final (°C)', 'type': 'text'},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
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
        {'key': 'hora', 'label': 'Hora', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'temperatura', 'label': 'Temperatura (°C)', 'type': 'number', 'required': true},
        {'key': 'humedad', 'label': 'Humedad relativa (%)', 'type': 'number'},
        {'key': 'presion', 'label': 'Presión (kPa)', 'type': 'number'},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
      ],
    },
    {
      'key': 'campanas',
      'label': 'Campanas de Flujo Laminar',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora', 'label': 'Hora', 'type': 'time', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text'},
        {'key': 'campana1', 'label': 'Campana 1', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA']},
        {'key': 'campana2', 'label': 'Campana 2', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA']},
        {'key': 'campana3', 'label': 'Campana 3', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA']},
        {'key': 'limpieza_previa', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SI', 'NO']},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
      ],
    },
    {
      'key': 'centrifugadoras',
      'label': 'Centrifugadoras',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text'},
        {'key': 'centrifuga1', 'label': 'Centrifugadora 1', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA']},
        {'key': 'centrifuga2', 'label': 'Centrifugadora 2', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA']},
        {'key': 'centrifuga3', 'label': 'Centrifugadora 3', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA']},
        {'key': 'limpieza_previa', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SI', 'NO']},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
      ],
    },
    {
      'key': 'microscopios',
      'label': 'Microscopios',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
        {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time'},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
        {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text'},
        {'key': 'microscopios_usados', 'label': 'Microscopios Utilizados', 'type': 'text'},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
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
        {'key': 'actividad', 'label': 'Actividad Realizada', 'type': 'text'},
        {'key': 'ph_obtenido', 'label': 'pH Obtenido / Calibración', 'type': 'text'},
      ],
      'fields': [
        {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
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
      'key': 'despacho_cajas',
      'label': 'Despacho de Cajas Celulares y Exosomas',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill', 'required': true},
      ],
      'activities_table': {
        'label': 'Productos Despachados',
        'key': 'despachos',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 60},
          {'key': 'presentacion', 'label': 'Presentación (Mill)', 'type': 'select', 'options': ['30M', '50M', '100M', 'EXOSOMAS'], 'width': 120},
          {'key': 'volumen', 'label': 'Volumen (CC)', 'type': 'text', 'width': 80},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['SISTEMICO', 'ARTICULAR', 'ARTICULAR RODILLA', 'TIROIDES'], 'width': 120},
          {'key': 'tejido', 'label': 'Tejido', 'type': 'select', 'options': ['TEJIDO ADIPOSO', 'PLACENTA', 'MEMBRANA', 'PULPA', 'ENDOMETRIO', 'AUTOLOGAS'], 'width': 130},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 150},
          {'key': 'enviado_a', 'label': 'Enviado A', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'QUANTUM', 'HOSPITAL', 'CLINICA PRIVADA', 'OTRO'], 'width': 130},
          {'key': 'pedido_por', 'label': 'Pedido Por', 'type': 'select', 'options': _medicos, 'width': 130},
          {'key': 'notas', 'label': 'Notas / Continuación', 'type': 'text', 'width': 200},
        ],
      },
      'fields': [],
    },
    {
      'key': 'misid',
      'label': 'MISID (Daño al ADN)',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Registro MISID',
        'key': 'misids',
        'columns': [
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'select', 'options': ['25', '50', '75', '100'], 'width': 90},
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['MISID', 'MISID ADVANCE', 'TRATAMIENTO AL DAÑO DEL ADN'], 'width': 170},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 150},
          {'key': 'enviado_a', 'label': 'Enviado A', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'QUANTUM'], 'width': 130},
          {'key': 'pedido_por', 'label': 'Pedido Por', 'type': 'select', 'options': _medicos, 'width': 130},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 250},
        ],
      },
      'fields': [],
    },
    {
      'key': 'nk',
      'label': 'NK (Natural Killer)',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Registro NK',
        'key': 'nks',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 60},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'text', 'width': 80},
          {'key': 'tejido', 'label': 'Tejido / Tipo', 'type': 'select', 'options': ['Autologas', 'Alogenicas'], 'width': 100},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 150},
          {'key': 'enviado_a', 'label': 'Enviado A', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'QUANTUM'], 'width': 130},
          {'key': 'pedido_por', 'label': 'Pedido Por', 'type': 'select', 'options': _medicos, 'width': 130},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 250},
        ],
      },
      'fields': [],
    },
    {
      'key': 'otros_productos',
      'label': 'Otros Productos (Medio Condicionado)',
      'type': 'daily_log',
      'general_fields': [
        {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
        {'key': 'responsable', 'label': 'Responsable', 'type': 'autofill'},
      ],
      'activities_table': {
        'label': 'Salida de Productos',
        'key': 'productos',
        'columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 60},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'text', 'width': 80},
          {'key': 'producto', 'label': 'Producto', 'type': 'text', 'width': 180},
          {'key': 'enviado_a', 'label': 'Enviado A', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'EXTERNO'], 'width': 130},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 250},
        ],
      },
      'fields': [],
    },
  ],
};

FormModuleDef _solucionCobreModule() => {
  'module': 'solucion_cobre',
  'label': 'Solución de Iones de Cobre',
  'icon': 'science',
  'color': '0xFF00BCD4',
  'sections': [
    {
      'key': 'preparacion',
      'label': 'Preparación y Actividades del Día',
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
          {'key': 'descripcion', 'label': 'Descripción de la Actividad', 'type': 'text', 'width': 350},
          {'key': 'resultados', 'label': 'Observaciones / Resultados', 'type': 'text', 'width': 350},
        ],
      },
      'fields': [
        {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
      ],
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
        {'key': 'paciente', 'label': 'Paciente / Donante', 'type': 'text'},
      ],
      'activities_table': {
        'label': 'Procesamiento de Muestras',
        'key': 'procesamiento',
        'columns': [
          {'key': 'codigo', 'label': 'Código Muestra', 'type': 'text', 'width': 130},
          {'key': 'tipo_muestra', 'label': 'Tipo de Muestra', 'type': 'select', 'options': ['Sangre', 'Tejido', 'Plasma', 'Suero', 'Orina', 'Saliva', 'Líquido Sinovial', 'Biopsia', 'Otro'], 'width': 140},
          {'key': 'origen', 'label': 'Origen', 'type': 'select', 'options': ['Paciente', 'Donante', 'Externo', 'Banco'], 'width': 100},
          {'key': 'tipo_procesamiento', 'label': 'Procesamiento', 'type': 'select', 'options': ['Centrifugación', 'Separación Celular', 'Filtración', 'Criopreservación', 'Lisis', 'Extracción ADN/ARN', 'Fijación'], 'width': 150},
          {'key': 'volumen_inicial', 'label': 'Vol. Inicial', 'type': 'number', 'width': 80},
          {'key': 'volumen_final', 'label': 'Vol. Final', 'type': 'number', 'width': 80},
          {'key': 'ubicacion', 'label': 'Ubicación', 'type': 'text', 'width': 120},
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
      'key': 'misid',
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
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'select', 'options': ['25', '50', '75', '100'], 'width': 90},
          {'key': 'tipo', 'label': 'Tipo', 'type': 'select', 'options': ['MISID', 'MISID ADVANCE', 'TRATAMIENTO AL DAÑO DEL ADN'], 'width': 170},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 150},
          {'key': 'enviado_a', 'label': 'Enviado A', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'QUANTUM'], 'width': 130},
          {'key': 'pedido_por', 'label': 'Pedido Por', 'type': 'select', 'options': _medicos, 'width': 130},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 250},
        ],
      },
      'fields': [],
    },
  ],
};
