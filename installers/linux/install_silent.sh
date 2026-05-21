#!/bin/bash
# BioLab LABSYNC - Silent Installer for Linux (Ubuntu/Debian)
# Usage: ./install_silent.sh [SERVER_URL]

set -e

SERVER_URL=${1:-"http://localhost:8000"}

echo "========================================"
echo "BioLab LABSYNC - Instalador Silencioso"
echo "========================================"
echo ""

INSTALL_DIR="$HOME/.local/share/biolab-labsync"
APPIMAGE_PATH="$INSTALL_DIR/BioLab-LABSYNC.AppImage"

if [ -f "$APPIMAGE_PATH" ]; then
    echo "[INFO] BioLab ya instalado en $INSTALL_DIR"
    echo "[INFO] Verificando actualizaciones..."
else
    echo "[INFO] Instalando BioLab LABSYNC..."
    mkdir -p "$INSTALL_DIR"
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

# Download AppImage
echo "[2/3] Descargando actualizacion..."
curl -s "$SERVER_URL/api/updates/file/BioLab-LABSYNC-$NEW_VERSION-linux.AppImage" -o "$APPIMAGE_PATH"

if [ ! -f "$APPIMAGE_PATH" ]; then
    echo "[ERROR] No se pudo descargar el instalador"
    exit 1
fi

chmod +x "$APPIMAGE_PATH"

# Create desktop entry
echo "[3/3] Creando entrada de escritorio..."
cat > "$HOME/.local/share/applications/biolab-labsync.desktop" << EOF
[Desktop Entry]
Name=BioLab LABSYNC
Comment=Sistema Operativo de Laboratorio
Exec=$APPIMAGE_PATH
Icon=utilities-terminal
Terminal=false
Type=Application
Categories=Utility;
EOF

echo ""
echo "[OK] Instalacion completada exitosamente"
echo "[OK] BioLab LABSYNC v$NEW_VERSION instalado en $INSTALL_DIR"
echo ""

# Create desktop shortcut if possible
if command -v xdg-desktop-icon &> /dev/null; then
    xdg-desktop-icon install "$HOME/.local/share/applications/biolab-labsync.desktop" 2>/dev/null || true
fi

echo "Iniciando aplicacion..."
nohup "$APPIMAGE_PATH" &>/dev/null &

# Cleanup
rm -f /tmp/labsync_version.json

echo ""
echo "========================================"
echo "Instalacion completada"
echo "========================================"
