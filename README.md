# LABSYNC ENTERPRISE v7.1
### Sistema Operativo de Laboratorio — Distribuido, Seguro, Offline-First y Auto-Update

Sistema completo de laboratorio con actualizacion automatica silenciosa en Windows, macOS, Linux, iOS y Android.

---

## Instalacion Automatica (Una vez, despues se actualiza solo)

### Windows
```powershell
# Una sola vez:
.\installers\windows\install_silent.bat http://TU-SERVIDOR:8000

# Para auto-update permanente (agregar al startup):
schtasks /create /tn "BioLab Update Checker" /tr "powershell -ExecutionPolicy Bypass -File \"C:\BioLab\installers\windows\update_checker.ps1\"" /sc onlogon /rl highest
```

### macOS
```bash
# Una sola vez:
chmod +x installers/macos/install_silent.sh
./installers/macos/install_silent.sh http://TU-SERVIDOR:8000

# Para auto-update permanente:
echo "./installers/macos/update_checker.sh http://TU-SERVIDOR:8000 &" >> ~/.zshrc
```

### Linux (Ubuntu)
```bash
# Una sola vez:
chmod +x installers/linux/install_silent.sh
./installers/linux/install_silent.sh http://TU-SERVIDOR:8000

# Para auto-update permanente (systemd):
sudo cp installers/linux/biolab-update.service /etc/systemd/system/
sudo systemctl enable biolab-update
sudo systemctl start biolab-update
```

**Despues de la instalacion inicial, las apps se actualizan SOLAS cada 30 minutos.**

---

## Probar la app AHORA (desarrollo)

### 1. Backend (FastAPI)
```bash
cd biolab-labsync/backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

### 2. Web (cliente actual)
```bash
# Doble clic en Iniciar BioLab.bat
# O desde terminal:
powershell -ExecutionPolicy Bypass -File server.ps1
```
Abre: http://localhost:8765

### 3. Flutter Desktop (si tienes Flutter SDK)
```bash
cd biolab-labsync/frontend_flutter
flutter pub get
flutter run -d windows   # Windows
flutter run -d macos     # macOS
flutter run -d linux     # Ubuntu
```

---

## Como funciona el Auto-Update

```
┌─────────────────────────────────────────────────────────┐
│                    SERVIDOR CENTRAL                      │
│  FastAPI + version.json + binarios en backend/updates/   │
└────────────────────────┬────────────────────────────────┘
                         │
          Cada 30 minutos verifica version
                         │
        ┌────────────────┼────────────────┐
        ▼                ▼                ▼
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │ PC Lab 1 │    │ Laptop 2 │    │ PC Casa  │
  │ Windows  │    │ macOS    │    │ Linux    │
  └────┬─────┘    └────┬─────┘    └────┬─────┘
       │               │               │
       └───────────────┼───────────────┘
                       │
          Si hay nueva version:
          1. Descarga silenciosa
          2. Cierra app si corre
          3. Instala
          4. Reinicia app
          TODO SIN PEDIR PERMISO
```

---

## Publicar nueva version (actualizar todas las PCs)

### Paso 1: Compilar
```bash
cd frontend_flutter
flutter build windows --release
flutter build macos --release
flutter build linux --release
```

### Paso 2: Colocar binarios
```bash
cp build/windows/x64/runner/Release/* backend/updates/
cp build/macos/Build/Products/Release/*.dmg backend/updates/
cp build/linux/x64/release/bundle/*.AppImage backend/updates/
```

### Paso 3: Actualizar version.json
```json
{
  "version": "7.2.0",
  "mandatory": false,
  "release_notes": "Nuevas mejoras..."
}
```

### Paso 4: Push
```bash
git add -A
git commit -m "release: v7.2.0"
git push
```

**En maximo 30 minutos, TODAS las PCs instaladas se actualizan solas.**

---

## Credenciales

| Usuario | Rol | PIN |
|---|---|---|
| usr-admin | ADMIN | 1234 |
| usr-jefe | JEFE | 0000 |
| usr-t1 | LABORATORIO | 1111 |
| usr-auditor | AUDITOR | 2222 |
| usr-dueno | DUEÑO | 3333 |

---

## Arquitectura

- **Offline-first**: SQLite local, sincronizacion cuando hay red
- **Multiplataforma**: Windows, macOS, Linux, iOS, Android
- **Auto-update**: Verifica cada 30 min, instala silenciosamente
- **JWT auth**: Tokens seguros por capa
- **Auditoria completa**: Cada accion queda registrada
- **Calendario operativo**: Colores semanticos, cierre diario
- **Formularios dinamicos**: Templates JSON, sin rehacer app

---

*LABSYNC Enterprise v7.1 — Sistema Operativo de Laboratorio*
