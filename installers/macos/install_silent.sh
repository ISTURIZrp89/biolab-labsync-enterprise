#!/bin/bash
# BioLab LABSYNC - Silent Installer for macOS
# Usage: ./install_silent.sh [SERVER_URL]

set -e

SERVER_URL=${1:-"http://localhost:8000"}

echo "========================================"
echo "BioLab LABSYNC - Instalador Silencioso"
echo "========================================"
echo ""

APP_PATH="/Applications/BioLab LABSYNC.app"

if [ -d "$APP_PATH" ]; then
    echo "[INFO] BioLab ya instalado en /Applications/"
    echo "[INFO] Verificando actualizaciones..."
else
    echo "[INFO] Instalando BioLab LABSYNC..."
fi

# Download version info
echo "[1/3] Verificando version..."
curl -s "$SERVER_URL/api/updates/version.json" -o /tmp/labsync_version.json

if [ ! -f /tmp/labsync_version.json ]; then
    echo "[ERROR] No se pudo conectar al servidor: $SERVER_URL"
    echo "[ERROR] Verifica que el backend este corriendo"
    exit 1
fi

NEW_VERSION=$(python3 -c "import json; print(json.load(open('/tmp/labsync_version.json'))['version'])" 2>/dev/null || echo "7.1.0")

echo "[INFO] Version disponible: $NEW_VERSION"

# Download DMG
echo "[2/3] Descargando actualizacion..."
curl -s "$SERVER_URL/api/updates/file/BioLab-LABSYNC-$NEW_VERSION-macos.dmg" -o /tmp/biolab_update.dmg

if [ ! -f /tmp/biolab_update.dmg ]; then
    echo "[ERROR] No se pudo descargar el instalador"
    exit 1
fi

# Mount and install
echo "[3/3] Instalando silenciosamente..."
MOUNT_POINT=$(hdiutil attach /tmp/biolab_update.dmg -nobrowse -quiet | tail -n 1 | awk '{print $NF}')

if [ -d "$MOUNT_POINT/BioLab LABSYNC.app" ]; then
    cp -R "$MOUNT_POINT/BioLab LABSYNC.app" /Applications/
    hdiutil detach "$MOUNT_POINT" -quiet
fi

echo ""
echo "[OK] Instalacion completada exitosamente"
echo "[OK] BioLab LABSYNC v$NEW_VERSION instalado en /Applications/"
echo ""

echo "Iniciando aplicacion..."
open "$APP_PATH"

# Cleanup
rm -f /tmp/biolab_update.dmg
rm -f /tmp/labsync_version.json

echo ""
echo "========================================"
echo "Instalacion completada"
echo "========================================"
