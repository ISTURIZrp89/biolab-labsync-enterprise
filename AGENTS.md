# BioLab LABSYNC Enterprise — Guia de contexto para IA

## Stack
- **Frontend**: Flutter (Dart) + Riverpod + drift (SQLite local)
- **Backend**: Python FastAPI asincrono + SQLite/PostgreSQL
- **Sync**: REST API + LAN discovery (UDP)
- **Infra**: Docker Compose (opcional)

## Arquitectura

### Backend (packages/backend/)
```
app/
  core/       → Config, DB async, JWT, dependencias, security
  models/     → SQLAlchemy ORM (Usuario, FormEntry, etc.)
  schemas/    → Pydantic validation
  modules/    → Modulos independientes (auth, sync, calendar, etc.)
  services/   → PDF, rate limiter
```

### Frontend (packages/frontend/)
```
lib/
  core/       → Theme, constants, logger
  data/       → drift database + providers
  domain/     → Entidades
  presentation/ → Screens + Widgets
  services/   → Auth, Sync, Backup, etc.
  sync/       → SyncEngine + LAN Discovery
  security/   → Permisos (PermissionService)
```

## Comandos
```bash
# Frontend
cd packages/frontend && flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter run -d windows

# Backend
cd packages/backend && python -m venv .venv && .\.venv\Scripts\pip install -e ".[dev]" && uvicorn app.main:app --reload

# Tests
cd packages/backend && pytest
cd packages/frontend && flutter test
```

## Seguridad
- Secret key generada aleatoriamente (no hardcodeada)
- PINs y tokens en flutter_secure_storage (no SharedPreferences)
- RBAC con roles: ADMIN, JEFE, LABORATORIO, AUDITOR, DUENO
- Docker container como usuario non-root
- Redis con autenticación

## Notas clave
- Riverpod en vez de Provider
- drift en vez de sqflite
- Backend async con SQLAlchemy asincrono
- Seeds de usuarios con credenciales aleatorias (primera ejecución)
- logging en vez de print() en backend
- flutter_secure_storage en vez de SharedPreferences para secrets
