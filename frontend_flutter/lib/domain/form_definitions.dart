typedef FormFieldDef = Map<String, dynamic>;
typedef FormSectionDef = Map<String, dynamic>;
typedef FormModuleDef = Map<String, dynamic>;

final List<FormModuleDef> formModules = [
  {
    'module': 'incubadoras',
    'label': 'Incubadoras',
    'icon': 'thermostat',
    'color': '0xFFFF6B6B',
    'sections': [
      {
        'key': 'registro',
        'label': 'Registro',
        'fields': [
          {'key': 'equipo', 'label': 'Equipo', 'type': 'select', 'options': ['SANYO', 'HERACELL', 'STERI-CULT'], 'required': true},
          {'key': 'usuario', 'label': 'Usuario', 'type': 'text', 'required': true},
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'hora', 'label': 'Hora', 'type': 'time', 'required': true},
          {'key': 'temperatura', 'label': 'Temperatura', 'type': 'number', 'unit': '°C', 'required': true},
          {'key': 'co2', 'label': 'CO2', 'type': 'number', 'unit': '%', 'required': true},
          {'key': 'estado', 'label': 'Estado', 'type': 'select', 'options': ['ok', 'NA'], 'required': true},
        ],
      },
    ],
  },
  {
    'module': 'autoclaves',
    'label': 'Autoclaves',
    'icon': 'local_fire_department',
    'color': '0xFFFFA94D',
    'sections': [
      {
        'key': 'ciclos',
        'label': 'Ciclos',
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'ciclo_no', 'label': 'Ciclo No.', 'type': 'number', 'required': true},
          {'key': 'contenido', 'label': 'Contenido', 'type': 'text', 'required': true},
          {'key': 'temperatura', 'label': 'Temperatura', 'type': 'number', 'unit': '°C', 'required': true},
          {'key': 'presion', 'label': 'Presion', 'type': 'number', 'unit': 'atm', 'required': true},
          {'key': 'tiempo_esteril', 'label': 'Tiempo Esteril', 'type': 'text', 'required': true},
          {'key': 'indicador_quimico', 'label': 'Indicador Quimico', 'type': 'text', 'required': true},
          {'key': 'operador', 'label': 'Operador', 'type': 'text', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'mantenimiento',
        'label': 'Mantenimiento',
        'fields': [
          {'key': 'fecha_servicio', 'label': 'Fecha Servicio', 'type': 'date', 'required': true},
          {'key': 'tecnico_empresa', 'label': 'Tecnico/Empresa', 'type': 'text', 'required': true},
          {'key': 'tipo_servicio', 'label': 'Tipo Servicio', 'type': 'text', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
          {'key': 'prox_revision', 'label': 'Proxima Revision', 'type': 'date', 'required': true},
        ],
      },
      {
        'key': 'testigos',
        'label': 'Testigos',
        'fields': [
          {'key': 'fecha_prueba', 'label': 'Fecha Prueba', 'type': 'date', 'required': true},
          {'key': 'tipo_indicador', 'label': 'Tipo Indicador', 'type': 'text', 'required': true},
          {'key': 'lote_caducidad', 'label': 'Lote/Caducidad', 'type': 'text', 'required': true},
          {'key': 'resultado', 'label': 'Resultado', 'type': 'select', 'options': ['Negativo', 'Positivo'], 'required': true},
          {'key': 'laboratorio', 'label': 'Laboratorio', 'type': 'text', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
    ],
  },
  {
    'module': 'ultracongeladores',
    'label': 'Ultracongeladores',
    'icon': 'ac_unit',
    'color': '0xFF4DABF7',
    'sections': [
      {
        'key': 'registro',
        'label': 'Registro',
        'fields': [
          {'key': 'modelo', 'label': 'Modelo', 'type': 'select', 'options': ['HAIER 100L', 'HAIER PB', 'THERMOFISHER'], 'required': true},
          {'key': 'usuario', 'label': 'Usuario', 'type': 'text', 'required': true},
          {'key': 'estado', 'label': 'Estado', 'type': 'text', 'initial': 'ACTIVO'},
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
          {'key': 'temp_inicial', 'label': 'Temp. Inicial', 'type': 'number', 'unit': '°C', 'required': true},
          {'key': 'hora_termino', 'label': 'Hora Termino', 'type': 'time', 'required': true},
          {'key': 'temp_final', 'label': 'Temp. Final', 'type': 'number', 'unit': '°C', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
    ],
  },
  {
    'module': 'equipos',
    'label': 'Equipos',
    'icon': 'precision_manufacturing',
    'color': '0xFF69DB7C',
    'sections': [
      {
        'key': 'condiciones_ambientales',
        'label': 'Condiciones Ambientales',
        'fields': [
          {'key': 'nombre', 'label': 'Nombre', 'type': 'text', 'required': true},
          {'key': 'fecha_hora', 'label': 'Fecha/Hora', 'type': 'datetime', 'required': true},
          {'key': 'temperatura', 'label': 'Temperatura', 'type': 'number', 'unit': '°C', 'required': true},
          {'key': 'humedad', 'label': 'Humedad', 'type': 'number', 'unit': '%', 'required': true},
          {'key': 'presion', 'label': 'Presion', 'type': 'number', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
          {'key': 'responsable', 'label': 'Responsable', 'type': 'text', 'required': true},
        ],
      },
      {
        'key': 'campanas_flujo_laminar',
        'label': 'Campanas Flujo Laminar',
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'nombre', 'label': 'Nombre', 'type': 'text', 'required': true},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'required': true},
          {'key': 'campana1', 'label': 'Campana 1', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'required': true},
          {'key': 'campana2', 'label': 'Campana 2', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'required': true},
          {'key': 'campana3', 'label': 'Campana 3', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'required': true},
          {'key': 'limpieza_previa', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SI', 'NO'], 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'centrifugadoras',
        'label': 'Centrifugadoras',
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'nombre', 'label': 'Nombre', 'type': 'text', 'required': true},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'required': true},
          {'key': 'centrifugadora1', 'label': 'Centrifugadora 1', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'required': true},
          {'key': 'centrifugadora2', 'label': 'Centrifugadora 2', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'required': true},
          {'key': 'centrifugadora3', 'label': 'Centrifugadora 3', 'type': 'select', 'options': ['ENCENDIDA', 'NO ENCENDIDA'], 'required': true},
          {'key': 'limpieza_previa', 'label': 'Limpieza Previa', 'type': 'select', 'options': ['SI', 'NO'], 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'microscopio',
        'label': 'Microscopio',
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
          {'key': 'microscopio', 'label': 'Microscopio', 'type': 'select', 'options': ['1 INVERTIDO', '2 COMPUESTO', '3 ESTEREOSCOPIO'], 'required': true},
          {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time', 'required': true},
          {'key': 'nombre', 'label': 'Nombre', 'type': 'text', 'required': true},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'potenciometro',
        'label': 'Potenciometro',
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
          {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time', 'required': true},
          {'key': 'nombre', 'label': 'Nombre', 'type': 'text', 'required': true},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'required': true},
          {'key': 'ph_obtenido', 'label': 'pH Obtenido', 'type': 'text', 'required': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
        ],
      },
    ],
  },
  {
    'module': 'procesamiento',
    'label': 'Procesamiento',
    'icon': 'biotech',
    'color': '0xFFB197FC',
    'sections': [
      {
        'key': 'cajas_exosomas',
        'label': 'Cajas y Exosomas',
        'mode': 'table',
        'table_columns': [
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
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'required': true},
          {'key': 'presentacion', 'label': 'Presentacion', 'type': 'select', 'options': ['100M', '50M', '30M', 'EXOSOMAS'], 'required': true},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['5CC', '3CC', '2CC', '1CC'], 'required': true},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['SISTEMICO', 'ARTICULAR RODILLA', 'ARTICULAR CADERA'], 'required': true},
          {'key': 'tejido', 'label': 'Tejido', 'type': 'select', 'options': ['PLACENTA', 'TEJIDO ADIPOSO', 'Autologas', 'ENDOMETRIO'], 'required': true},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'required': true},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'select', 'options': ['IMMUNOTHERAPY', 'QUANTUM'], 'required': true},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'select', 'options': ['DR. JAVIER ARENAS'], 'required': true},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'misids',
        'label': 'MISIDs',
        'mode': 'table',
        'table_columns': [
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'number', 'width': 90},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['MISID ADVANCE', 'TRATAMIENTO AL DAÑO DEL ADN'], 'width': 160},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'volumen_ml', 'label': 'Volumen (ml)', 'type': 'number', 'required': true},
          {'key': 'uso', 'label': 'Uso', 'type': 'select', 'options': ['MISID ADVANCE', 'TRATAMIENTO AL DAÑO DEL ADN'], 'required': true},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'required': true},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'required': true},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'text', 'required': true},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'nk',
        'label': 'NK',
        'mode': 'table',
        'table_columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 70},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['1CC'], 'width': 80},
          {'key': 'tejido', 'label': 'Tejido', 'type': 'select', 'options': ['Autologas', 'Alogenicas'], 'width': 100},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'required': true},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'select', 'options': ['1CC'], 'required': true},
          {'key': 'tejido', 'label': 'Tejido', 'type': 'select', 'options': ['Autologas', 'Alogenicas'], 'required': true},
          {'key': 'paciente', 'label': 'Paciente', 'type': 'text', 'required': true},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'required': true},
          {'key': 'pedido_por', 'label': 'Pedido por', 'type': 'text', 'required': true},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'multiline': true},
        ],
      },
      {
        'key': 'otros_productos',
        'label': 'Otros Productos',
        'mode': 'table',
        'table_columns': [
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'width': 70},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'text', 'width': 80},
          {'key': 'producto', 'label': 'Producto', 'type': 'text', 'width': 130},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'width': 110},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'width': 150},
        ],
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'pedido', 'label': 'Pedido', 'type': 'number', 'required': true},
          {'key': 'volumen', 'label': 'Volumen', 'type': 'text', 'required': true},
          {'key': 'producto', 'label': 'Producto', 'type': 'text', 'required': true},
          {'key': 'enviado_a', 'label': 'Enviado a', 'type': 'text', 'required': true},
          {'key': 'notas', 'label': 'Notas', 'type': 'text', 'multiline': true},
        ],
      },
    ],
  },
  {
    'module': 'bitacora',
    'label': 'Bitacora General',
    'icon': 'book',
    'color': '0xFFE91E63',
    'sections': [
      {
        'key': 'registro',
        'label': 'Registro de Actividad',
        'fields': [
          {'key': 'fecha', 'label': 'Fecha', 'type': 'date', 'required': true},
          {'key': 'hora_inicio', 'label': 'Hora Inicio', 'type': 'time', 'required': true},
          {'key': 'hora_fin', 'label': 'Hora Fin', 'type': 'time', 'required': true},
          {'key': 'responsable', 'label': 'Responsable', 'type': 'text', 'required': true},
          {'key': 'tipo_actividad', 'label': 'Tipo de Actividad', 'type': 'select', 'options': ['Cultivo celular', 'Procesamiento', 'Mantenimiento', 'Control de calidad', 'Aislamiento', 'Otro'], 'required': true},
          {'key': 'actividad', 'label': 'Actividad', 'type': 'text', 'multiline': true, 'required': true},
          {'key': 'equipos_usados', 'label': 'Equipos Usados', 'type': 'text', 'multiline': true},
          {'key': 'observaciones', 'label': 'Observaciones', 'type': 'text', 'multiline': true},
          {'key': 'firma_responsable', 'label': 'Firma Responsable', 'type': 'text', 'required': true},
          {'key': 'recursos_utilizados', 'label': 'Recursos Utilizados', 'type': 'text', 'multiline': true},
          {'key': 'incidencias', 'label': 'Incidencias', 'type': 'text', 'multiline': true},
        ],
      },
    ],
  },
];

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
