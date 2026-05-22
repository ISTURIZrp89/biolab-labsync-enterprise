# BioLab LABSYNC

Sistema de gestión de bitácoras para laboratorio. Multiplataforma (Windows, macOS, Linux, iOS, Android) con sincronización offline-first.

## Stack

- **Frontend**: Flutter 3.16+ con Provider (gestión de estado)
- **Backend**: FastAPI (Python 3.11+) con SQLAlchemy
- **Base de datos**: SQLite cifrada (local) + PostgreSQL (servidor remoto)
- **Sincronización**: Motor offline-first con cola de sync y resolución de conflictos

## Estructura

```
biolab-labsync/
├── frontend_flutter/
│   └── lib/
│       ├── ai/              # IA ligera Fase 1: sugerencias, validación, predicción
│       ├── data/            # DB, repositorios, migraciones schema (v5)
│       ├── domain/          # Entidades, definiciones de formularios (6 módulos)
│       ├── presentation/    # Screens (dashboard, formularios, reportes, settings)
│       ├── security/        # AuthService, PermissionService, EditLockService
│       ├── services/        # ClosureService, UserService, DashboardService
│       ├── sync/            # SyncEngine, LAN discovery, LAN sync server
│       └── theme/           # Tema oscuro profesional (OmniTheme)
├── backend/
│   ├── ai/                  # API IA (sugerencias, validación, predicción)
│   ├── routers/             # FastAPI routers
│   └── main.py              # Entry point con seed users
├── docs/                    # Documentación
└── scripts/                 # Utilidades
```

## Inicio rápido

```bash
# Frontend
cd frontend_flutter
flutter pub get
flutter run

# Backend
cd backend
python -m venv .venv
.venv\Scripts\activate  # Windows
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

## Funcionalidades

### Formularios de laboratorio (6 módulos)
Cada módulo con secciones, campos generales, tablas de actividades y recursos:

- **Incubadoras**: Control CO₂, temperatura, limpieza, calibración, alarmas
- **Autoclaves**: Ciclos (liquidos/residuos/material), indicadores biológicos/químicos, mantenimiento
- **Ultracongeladores**: Temperatura, niveles LN₂/CO₂, alarmas, respaldo, inventario
- **Equipos**: Condiciones ambientales, campanas bioseguridad, centrífugas, microscopio, potenciómetro
- **Procesamiento**: Cajas/Exosomas, MISIDs, NK, Otros procesamientos
- **Bitácora General**: Actividades del día, recursos utilizados, incidencias, acuerdos

### Sistema de roles y permisos

| Rol Sistema | Acceso | Permiso |
|-------------|--------|---------|
| ADMIN       | Todos los módulos + config | owner |
| JEFE        | Todos excepto config | edit |
| LABORATORIO | Módulos operativos | edit |
| AUDITOR     | Solo reportes | view |
| DUEÑO       | Todos + config | owner |

- **Cargo operativo** (TÉCNICO, BIÓLOGO, QFB, JEFE DE LABORATORIO, ADMINISTRADOR) para reportes
- **Autofill inteligente** al login: nombre, cargo, área, supervisor, firma, turno
- Gestión de usuarios desde Configuración con PIN de 4 dígitos

### Sincronización offline-first

- Cola de cambios locales con reintento automático
- Resolución de conflictos por versión (server_wins)
- Sincronización periódica cada 5 minutos
- Sincronización por LAN entre pares descubiertos automáticamente
- Log de sincronización con historial (100 entradas)
- Indicador visual de estado (verde en línea, rojo desconectado)

### Cierres operativos

- Cierre diario con nota obligatoria
- Cierre mensual con verificación de datos
- Reapertura limitada a 3 días con motivo y auditoría
- Calendario con color-coded: verde (cerrado), naranja (reabierto), azul (con datos)

### Captura rápida

- Navegación TAB entre campos con ENTER para avanzar
- Duplicar filas en tablas
- Copiar datos de entrada anterior
- Pegar desde portapapeles (formato TSV)
- Historial de valores usados previamente

### Reportes ISO

- PDF profesional con folio, emisión, header corporativo y footer controlado
- Resumen por módulo con tabla coloreada
- Detalle de registros con datos completos
- Exportación a Excel
- Filtro por rango de fechas y módulo

### Seguridad

- Sesión con timeout de inactividad (30 min) y duración máxima (8h)
- Bloqueo de edición concurrente (EditLock por entrada)
- Permisos granulares por módulo (view/edit/owner)
- PIN de acceso offline (fallback)
- Auditoría de cambios y sincronización

### IA Operativa Ligera (Fase 1)

Sistema de reglas inteligentes para asistencia operativa sin modelos grandes:

- **Sugerencias contextuales**: Basadas en historial del campo + contexto del formulario
- **Autocompletado inteligente**: Predice valores (hora_fin desde hora_inicio, turno según hora)
- **Validación automática**: Detecta campos requeridos faltantes, fechas inconsistentes, reactivos vencidos
- **Bloqueo contextual**: Sugiere el siguiente campo a llenar según el campo actual
- **Historial persistente**: Almacena los últimos 50 valores por campo en SharedPreferences
- **Desacoplado**: El sistema funciona aunque la IA esté deshabilitada

### Sistema de estados profesional

Cada entrada tiene un estado en su ciclo de vida:

| Estado | Descripción |
|--------|-------------|
| Borrador | En edición, no finalizado |
| Pendiente | Guardado, requiere revisión |
| Completado | Datos completos ingresados |
| Revisado | Verificado por supervisor |
| Corregido | Ajustes realizados post-revisión |
| Cerrado | Bloqueado por cierre operativo |
| Reabierto | Reactivado post-cierre (máx 3 días) |
| Justificado | Día no laborado con justificación |
| Cancelado | Descartado por administrador |

El calendario muestra indicadores visuales: ✓ cerrado, ↩ reabierto, ● hoy, contador de entradas.

### Autoguardado

- Guardado automático cada 30 segundos como borrador en SharedPreferences
- Recuperación de borrador al abrir el formulario nuevamente
- Indicador de cambios no guardados (_dirty flag)

### Laboratorio clínico

- **MISID**: Registro de ingresos, procesamiento y resultados
- **NK (Natural Killers)**: Citotoxicidad, seguimiento de donantes
- **Exosomas**: Aislamiento, caracterización, aplicaciones
- **Cultivo celular en cajas**: Control deconfluencia, cambios de medio, pases
- **Respaldo de ultracongeladores**: Niveles de LN₂/CO₂ en tiempo real

## Login offline (PINs de emergencia)

| PIN   | Rol      | Cargo operativo     |
|-------|----------|---------------------|
| 1234  | ADMIN    | ADMINISTRADOR       |
| 0000  | JEFE     | JEFE DE LABORATORIO |
| 1111  | LABORATORIO | TÉCNICO          |
| 2222  | AUDITOR  | QFB                 |
| 3333  | DUEÑO    | DIRECTOR GENERAL    |

## Configuración de red LAN

1. Activar "Sincronización por red local" en Configuración
2. Puerto UDP descubrimiento (default: 8765)
3. Puerto HTTP servidor (default: 8766)
4. Las PCs en la misma red se detectan automáticamente

## Licencia

Uso interno - BioLab
