# LABSYNC Enterprise - Installers & Auto-Update

## Instalacion Automatica

### Windows

**Instalacion inicial:**
```powershell
# Descargar y ejecutar
.\installers\windows\install_silent.bat http://TU-SERVIDOR:8000
```

**Update checker (corre en background):**
```powershell
# Agregar al startup
schtasks /create /tn "BioLab Update Checker" /tr "powershell -ExecutionPolicy Bypass -File \"%CD%\installers\windows\update_checker.ps1\"" /sc onlogon /rl highest
```

### macOS

**Instalacion inicial:**
```bash
chmod +x installers/macos/install_silent.sh
./installers/macos/install_silent.sh http://TU-SERVIDOR:8000
```

**Update checker (corre en background):**
```bash
# Agregar al login items
chmod +x installers/macos/update_checker.sh
echo "./installers/macos/update_checker.sh http://TU-SERVIDOR:8000 &" >> ~/.zshrc
```

### Linux (Ubuntu)

**Instalacion inicial:**
```bash
chmod +x installers/linux/install_silent.sh
./installers/linux/install_silent.sh http://TU-SERVIDOR:8000
```

**Update checker (systemd service):**
```bash
sudo cp installers/linux/biolab-update.service /etc/systemd/system/
sudo systemctl enable biolab-update
sudo systemctl start biolab-update
```

---

## Como funciona el auto-update

1. **Update checker** corre en background cada 30 minutos
2. Verifica `version.json` en el servidor
3. Si hay nueva version → descarga silenciosamente
4. Cierra la app si esta corriendo
5. Instala la nueva version
6. Reinicia la app automaticamente

**Todo sin intervencion del usuario.**

---

## Estructura de archivos

```
installers/
├── windows/
│   ├── install_silent.bat      # Instalador silencioso Windows
│   └── update_checker.ps1      # Update checker (PowerShell)
├── macos/
│   ├── install_silent.sh       # Instalador silencioso macOS
│   └── update_checker.sh       # Update checker (bash)
└── linux/
    ├── install_silent.sh       # Instalador silencioso Linux
    ├── update_checker.sh       # Update checker (bash)
    └── biolab-update.service   # Systemd service
```

---

## Publicar nueva version

1. Compilar para cada plataforma
2. Colocar binarios en `backend/updates/`
3. Actualizar `backend/version.json` con nueva version
4. Push al repo

Las apps instaladas se actualizaran solas en maximo 30 minutos.
