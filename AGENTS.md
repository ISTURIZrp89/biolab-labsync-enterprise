# BioLab LABSYNC Enterprise — Guía para IA

## Stack
- **Frontend**: Flutter (Dart) con Riverpod + drift + WebSockets
- **Backend**: Python FastAPI modular + PostgreSQL
- **Infra**: Docker Compose (Redis, PostgreSQL)

## Convenciones
- Commits en español, formato: `tipo: descripción`
- Clean Architecture: domain → data → presentation
- Riverpod: providers en archivos separados por feature
- drift: usar DAOs para cada entidad
- Backend: módulos independientes con router + service + schemas

## Comandos
```bash
# Frontend
cd packages/frontend
flutter pub get
flutter run -d windows
flutter test

# Backend
cd packages/backend
pip install -r requirements.txt
uvicorn app.main:app --reload

# Infra
docker compose up -d

# Pruebas backend
pytest

# Lint
cd packages/frontend && flutter analyze
cd packages/backend && ruff check .
```

## Estructura
```
packages/
  frontend/    → Flutter (Riverpod + drift)
  backend/     → FastAPI modular
  shared/      → Tipos/DTOs compartidos
```

## Notas
- No usar Provider legacy, solo Riverpod
- drift para toda la capa de datos local
- WebSockets para sync en tiempo real
- Alembic para migraciones de BD
