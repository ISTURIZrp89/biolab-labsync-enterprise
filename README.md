# BioLab LABSYNC

Sistema de gestión de bitácoras de laboratorio. Multiplataforma (Windows, macOS, Linux, iOS, Android).

## Stack

- **Frontend**: Flutter 3.16+ con Provider
- **Backend**: FastAPI (Python 3.11+)
- **Base de datos**: SQLite local + PostgreSQL remoto
- **Sincronización**: Engine offline-first con cola de sync

## Estructura

```
biolab-labsync/
├── frontend_flutter/       # App Flutter
│   └── lib/
│       ├── data/           # DB, repositorios, CSV mappings
│       ├── domain/         # Entidades, definiciones de formularios
│       ├── presentation/   # Screens y widgets
│       ├── security/       # Auth offline con PIN
│       ├── services/       # Actualización automática
│       ├── sync/           # Motor de sincronización
│       └── theme/          # Tema oscuro profesional
├── backend/                # API FastAPI
├── docs/                   # Documentación
└── scripts/                # Utilidades
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

## Login offline

| PIN   | Rol      |
|-------|----------|
| 1234  | Admin    |
| 0000  | Jefe     |
| 1111  | Técnico  |
| 2222  | Auditor  |
| 3333  | Dueño    |

## Módulos

- Incubadoras, Autoclaves, Ultracongeladores
- Equipos (Cond. ambientales, Campanas, Centrífugas, Microscopio, Potenciómetro)
- Procesamiento (Cajas/Exosomas, MISIDs, NK, Otros)
- Bitácora General
- Calendario operativo
- Reportes PDF/Excel
- Importación CSV

## Licencia

Uso interno - BioLab
