# BioLab LABSYNC Enterprise — Guia de contexto para IA

## Stack
- **Frontend**: Flutter (Dart) + Riverpod + drift (SQLite local)
- **Backend**: Python FastAPI asincrono + SQLite/PostgreSQL
- **Sync**: REST API + WebSockets + LAN discovery (UDP)
- **Infra**: Docker Compose (opcional)

## Arquitectura

### Backend (packages/backend/)
```
app/
  core/       → Config, DB async, JWT, dependencias
  models/     → SQLAlchemy ORM (Usuario, FormEntry, etc.)
  schemas/    → Pydantic validation
  modules/    → Modulos independientes (auth, sync, calendar, etc.)
  services/   → PDF, Google Drive, rate limiter
```

### Frontend (packages/frontend/)
```
lib/
  core/       → Theme, constants
  data/       → drift database + providers
  domain/     → Entidades
  presentation/ → Screens + Widgets
  services/   → Auth, Sync, Backup, etc.
  sync/       → SyncEngine + LAN Discovery
  security/   → Permisos
```

## Comandos
```bash
cd packages/frontend && flutter pub get && flutter run -d windows
cd packages/backend && pip install -r requirements.txt && uvicorn app.main:app --reload
cd packages/backend && pytest
```

## Notas clave
- Riverpod en vez de Provider
- drift en vez de sqflite
- Backend async con SQLAlchemy asincrono
- Seeds de usuarios y plantillas automaticos al iniciar backend
