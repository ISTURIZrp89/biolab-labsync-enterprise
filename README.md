# BioLab LABSYNC Enterprise v0.0.0.1

Sistema de bitácora digital para laboratorios clínicos. Multiplataforma (Windows, macOS, Linux).

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | Flutter + Riverpod + drift |
| Backend | Python FastAPI + PostgreSQL |
| Sync | REST API + LAN discovery (UDP) |
| Infra | Docker Compose |

## Requisitos

- Flutter >= 3.22
- Python >= 3.11
- Docker (opcional, para PostgreSQL + Redis)

## Inicio rápido

```powershell
.\setup.ps1
```

### Manual

```bash
# Frontend
cd packages/frontend
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run -d windows

# Backend
cd packages/backend
python -m venv .venv
.\.venv\Scripts\pip install -e ".[dev]"
.\.venv\Scripts\uvicorn app.main:app --reload

# Infraestructura (opcional para desarrollo)
docker compose up -d
```

## Estructura

```
packages/
  frontend/   → Flutter app (Riverpod + drift)
  backend/    → FastAPI modular
```

## Seguridad

- Secrets generados aleatoriamente (no hardcodeados)
- PINs y tokens almacenados en secure storage (frontend)
- RBAC con roles: ADMIN, JEFE, LABORATORIO, AUDITOR, DUENO
- Docker container ejecuta como usuario no-root
- Redis con autenticación

## Licencia

Uso empresarial. Ver repositorio de licencias.
