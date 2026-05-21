# LABSYNC Enterprise - Auto-Update System

## Como funciona el auto-update

### Flujo automatico

1. **Al iniciar la app** → Verifica `version.json` en el servidor
2. **Cada hora** → Revisa automaticamente si hay nueva version
3. **Si hay update** → Muestra dialog con release notes
4. **Usuario acepta** → Descarga e instala automaticamente

### Actualizar desde el repo

Cuando haces push al repo, las apps instaladas se actualizan asi:

#### Paso 1: Actualizar version en el servidor

```bash
# Editar backend/version.json
{
  "version": "7.2.0",
  "build": 2,
  "release_date": "2026-05-21",
  "mandatory": false,
  "release_notes": "Nuevas mejoras...",
  "downloads": {
    "windows": {
      "url": "http://TU-SERVIDOR:8000/api/updates/download/windows",
      "filename": "BioLab-LABSYNC-7.2.0-windows.exe"
    }
  }
}
```

#### Paso 2: Compilar nueva version

```bash
cd frontend_flutter
flutter build windows --release   # o macos/linux/ios/android
```

#### Paso 3: Colocar binario en servidor

```bash
# Copiar el binario compilado a una carpeta accesible
mkdir -p backend/updates
cp build/windows/x64/runner/Release/* backend/updates/
```

#### Paso 4: Push al repo

```bash
git add -A
git commit -m "release: v7.2.0"
git push
```

#### Paso 5: Las apps se actualizan solas

- Cada app verifica cada hora
- Al detectar nueva version → muestra dialog
- Usuario clic en "Actualizar" → descarga e instala

---

## Configurar update automatico SIN intervencion

### Opcion A: Update silencioso (recomendado para laboratorio)

En `version.json` poner `"mandatory": true`:

```json
{
  "mandatory": true
}
```

La app se actualiza sola sin preguntar.

### Opcion B: Script de actualizacion automatica

Crear script que corre en cada PC:

**Windows (update_checker.bat):**
```batch
@echo off
:loop
curl -s http://TU-SERVIDOR:8000/api/updates/version.json > version_check.json
for /f "tokens=*" %%i in ('findstr "version" version_check.json') do set NEW_VERSION=%%i
echo Verificando actualizaciones...
timeout /t 3600 /nobreak >nul
goto loop
```

**Linux/macOS (update_checker.sh):**
```bash
#!/bin/bash
while true; do
  curl -s http://TU-SERVIDOR:8000/api/updates/check?current_version=7.1.0
  sleep 3600
done
```

---

## Probar la app AHORA

### 1. Backend (FastAPI)

```bash
cd biolab-labsync/backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Verifica que funciona: http://localhost:8000/docs

### 2. Web (cliente actual)

```bash
# Doble clic en Iniciar BioLab.bat
# O:
powershell -ExecutionPolicy Bypass -File server.ps1
```

Abre: http://localhost:8765

### 3. Flutter Desktop (si tienes Flutter)

```bash
cd biolab-labsync/frontend_flutter
flutter pub get
flutter run -d windows   # Windows
flutter run -d macos     # macOS
flutter run -d linux     # Ubuntu
```

### 4. Verificar auto-update

```bash
# El backend sirve version.json en:
curl http://localhost:8000/api/updates/check?current_version=7.0.0

# Cambia version.json a 7.2.0 y la app detectara el update
```

---

## Credenciales de prueba

| Usuario | Rol | PIN |
|---|---|---|
| usr-admin | ADMIN | 1234 |
| usr-jefe | JEFE | 0000 |
| usr-t1 | LABORATORIO | 1111 |
| usr-auditor | AUDITOR | 2222 |
| usr-dueno | DUEÑO | 3333 |
