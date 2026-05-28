# BioLab LABSYNC Enterprise v7.0

Sistema de bitácora digital para laboratorios clínicos. Multiplataforma (Windows, macOS, Linux).

## Stack

| Capa | Tecnología |
|---|---|
| Frontend | Flutter + Riverpod + drift |
| Backend | Python FastAPI + PostgreSQL |
| Sync | WebSockets + Redis Pub/Sub |
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
flutter run -d windows

# Backend
cd packages/backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Infraestructura (opcional para desarrollo)
docker compose up -d
```

## Estructura

```
packages/
  frontend/   → Flutter app (Riverpod + drift)
  backend/    → FastAPI modular
```

## Licencia

Uso empresarial. Ver repositorio de licencias.
