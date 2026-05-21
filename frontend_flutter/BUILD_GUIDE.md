# LABSYNC Enterprise v7.1 — Guia de Compilacion Multiplataforma

## Plataformas Soportadas

| Plataforma | Estado | Notas |
|---|---|---|
| Windows 10/11 | ✅ Completo | .exe / .msi |
| macOS 12+ | ✅ Completo | .app / .dmg (Intel + Apple Silicon) |
| Ubuntu 20.04+ | ✅ Completo | .deb / AppImage |
| iOS 12+ (iPhone/iPad) | ✅ Completo | TestFlight / App Store |
| Android 8+ | ✅ Completo | .apk / .aab |

---

## Requisitos Previos

### Flutter SDK (todas las plataformas)

```bash
# Instalar Flutter 3.16+
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"
flutter doctor
```

### Windows

```powershell
# Instalar Visual Studio 2022 con "Desktop development with C++"
# Instalar Windows 10 SDK
flutter config --enable-windows-desktop
```

### macOS

```bash
# Instalar Xcode Command Line Tools
xcode-select --install

# Para iOS: Xcode completo desde App Store
flutter config --enable-macos-desktop
flutter config --enable-ios
```

### Ubuntu/Linux

```bash
# Dependencias
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev

# SQLite para Linux
sudo apt-get install libsqlite3-dev

flutter config --enable-linux-desktop
```

### iOS (desde macOS)

```bash
# Xcode requerido
# Abrir Xcode -> Preferences -> Locations -> Command Line Tools
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer

# Instalar CocoaPods
sudo gem install cocoapods

flutter config --enable-ios
```

---

## Compilar por Plataforma

### Preparacion (todas las plataformas)

```bash
cd frontend_flutter
flutter pub get
```

### Windows

```bash
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

### macOS

```bash
flutter build macos --release
# Output: build/macos/Build/Products/Release/BioLab\ LABSYNC.app
```

### Linux (Ubuntu)

```bash
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

### iOS (iPhone/iPad)

```bash
flutter build ios --release --no-codesign
# Para distribuir: abrir ios/Runner.xcworkspace en Xcode y firmar
```

### Android

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

## Ejecutar en Desarrollo

```bash
# Windows
flutter run -d windows

# macOS
flutter run -d macos

# Linux
flutter run -d linux

# iOS (simulador)
flutter run -d iPhone-15

# iOS (dispositivo conectado)
flutter run -d <device-id>

# Android
flutter run -d <device-id>
```

---

## Estructura del Proyecto

```
frontend_flutter/
├── lib/
│   ├── main.dart                    # Entry point multiplataforma
│   ├── data/
│   │   ├── db.dart                  # SQLite con deteccion de plataforma
│   │   ├── api_client.dart          # HTTP client con JWT
│   │   └── repositories/            # Repositorios de datos
│   ├── domain/
│   │   ├── entities/                # Modelos de dominio
│   │   └── repositories/            # Interfaces de repositorio
│   ├── presentation/
│   │   ├── screens/                 # Pantallas (login, dashboard, calendar, etc.)
│   │   └── widgets/                 # Widgets reutilizables
│   ├── security/
│   │   └── auth_service.dart        # Servicio de autenticacion
│   └── sync/
│       └── sync_engine.dart         # Motor de sincronizacion
├── pubspec.yaml                     # Dependencias multiplataforma
├── ios/                             # Configuracion iOS
├── android/                         # Configuracion Android
├── windows/                         # Configuracion Windows
├── macos/                           # Configuracion macOS
└── linux/                           # Configuracion Linux
```

---

## Notas de Compatibilidad

### Base de Datos (SQLite)

- **Windows/macOS/Linux**: Usa `sqflite_common_ffi` con FFI nativo
- **iOS/Android**: Usa `sqflite` nativo (sin FFI)
- La deteccion es automatica en `db.dart`

### Paths de Almacenamiento

- **Desktop**: `getApplicationSupportDirectory()`
- **Mobile**: `getApplicationDocumentsDirectory()`
- Gestionado automaticamente por `path_provider`

### Red

- HTTP funciona igual en todas las plataformas
- iOS requiere `NSLocalNetworkUsageDescription` en Info.plist (ya incluido)
- Android requiere `INTERNET` permission en AndroidManifest.xml (ya incluido)

---

## Distribucion

### Windows Installer

```bash
# Usar Inno Setup o WiX para crear instalador
# Los binarios estan en build/windows/x64/runner/Release/
```

### macOS DMG

```bash
# Usar create-dmg o appdmg
# La app esta en build/macos/Build/Products/Release/
```

### Linux .deb

```bash
# Empaquetar el bundle con dpkg-deb
# O usar AppImage para distribucion universal
```

### iOS TestFlight

```bash
# Firmar en Xcode con Apple Developer account
# Archivar y subir a App Store Connect
```

---

## Solucion de Problemas

### Linux: Error de SQLite

```bash
sudo apt-get install libsqlite3-dev
flutter clean && flutter pub get
```

### iOS: Error de CocoaPods

```bash
cd ios
pod install --repo-update
cd ..
```

### Windows: Error de compilacion

```powershell
# Verificar Visual Studio con workload de C++
flutter doctor -v
```

### macOS: Error de firma

```bash
# Para desarrollo local
flutter build macos --release --no-codesign
```
