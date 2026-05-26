# LABSYNC Enterprise

Sistema de gestion de bitacoras para laboratorio clinico. Multiplataforma (Windows, macOS, Linux) con licencia por activacion, auto-update, y modulo de IA distribuida.

## Requisitos

- Flutter 3.16+
- Git
- Token de GitHub con permiso `Contents: Read` en `ISTURIZrp89/biolab-labsync-license`

## Compilar

```powershell
.\build.ps1                    # Build para Windows
.\build.ps1 -Run               # Compila y ejecuta
.\build.ps1 -Platform macos    # Build para macOS
```

El token se inyecta via `--dart-define=LICENSE_GITHUB_TOKEN`. Se lee de la variable de entorno o se solicita interactivamente.

## Compilar sin el script

```powershell
$env:LICENSE_GITHUB_TOKEN = "ghp_..."
flutter run --dart-define=LICENSE_GITHUB_TOKEN=$env:LICENSE_GITHUB_TOKEN
```

## Estructura del proyecto

```
frontend_flutter/
├── lib/
│   ├── ai/distributed/     # IA distribuida (nodos, memoria compartida)
│   ├── data/               # Persistencia SQLite + API
│   ├── domain/             # Entidades y logica de negocio
│   ├── presentation/       # UI (screens, widgets, dialogs)
│   │   ├── screens/
│   │   │   ├── activation_screen.dart   # Activacion por licencia
│   │   │   ├── login_screen.dart        # Login con PIN offline
│   │   │   ├── main_scaffold.dart       # Navegacion principal
│   │   │   ├── settings_screen.dart     # Configuracion
│   │   │   ├── remote_access_screen.dart # VPS + auditoria
│   │   │   └── ai/                      # Paneles de IA
│   │   └── widgets/
│   │       └── update_dialog.dart        # Dialog de auto-update
│   ├── security/           # Auth, permisos, PIN offline
│   ├── services/
│   │   ├── license_service.dart   # Validacion de licencia
│   │   ├── update_service.dart    # Auto-update automatico
│   │   ├── audit_service.dart     # Auditoria de actividades
│   │   └── vps_service.dart       # Conexion remota VPS
│   ├── sync/               # Sincronizacion offline-first + LAN
│   └── theme/              # OmniTheme (violeta/cian/rosa)
├── .github/workflows/
│   └── build.yml           # CI/CD con inyeccion del token
├── build.ps1               # Script de build multiplataforma
└── build.sh                # Version Linux/macOS
```

## Licencias

Cada dispositivo requiere activacion con una clave `LABSYNC-SUCURSAL-XXXX-XXXX`. El repositorio privado `ISTURIZrp89/biolab-labsync-license` contiene:

- `license.json` — Hashes SHA256 por sucursal + comandos remotos (revoke/wipe)
- `update.json` — Versiones y enlaces de descarga para auto-update
- `license_manager.ps1` — Herramienta para generar claves y gestionar licencias

La app valida la licencia cada 24 horas contra el repositorio privado via GitHub API.

## CI/CD

El workflow `.github/workflows/build.yml` compila automaticamente en cada push a `master` usando el secreto `LICENSE_GITHUB_TOKEN`.
