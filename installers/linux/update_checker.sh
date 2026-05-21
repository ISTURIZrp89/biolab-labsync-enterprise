#!/bin/bash
# BioLab LABSYNC - Background Update Checker for Linux
# Runs on startup, checks for updates every 30 minutes
# Auto-downloads and installs if update is available

SERVER_URL=${1:-"http://localhost:8000"}
CHECK_INTERVAL=1800  # 30 minutes
INSTALL_DIR="$HOME/.local/share/biolab-labsync"
APPIMAGE_PATH="$INSTALL_DIR/BioLab-LABSYNC.AppImage"
CURRENT_VERSION="7.1.0"

echo "========================================"
echo "BioLab LABSYNC - Update Checker"
echo "========================================"
echo ""
echo "[INFO] Server: $SERVER_URL"
echo "[INFO] Check interval: $((CHECK_INTERVAL / 60)) minutes"
echo "[INFO] Install dir: $INSTALL_DIR"
echo ""

# Create install directory
mkdir -p "$INSTALL_DIR"

# Load current version if exists
if [ -f "$INSTALL_DIR/version.txt" ]; then
    CURRENT_VERSION=$(cat "$INSTALL_DIR/version.txt")
fi

check_and_update() {
    # Check for updates
    RESPONSE=$(curl -s "$SERVER_URL/api/updates/check?current_version=$CURRENT_VERSION&platform=linux")

    HAS_UPDATE=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['has_update'])" 2>/dev/null || echo "false")

    if [ "$HAS_UPDATE" = "True" ]; then
        NEW_VERSION=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['latest_version'])" 2>/dev/null || echo "")

        if [ -n "$NEW_VERSION" ]; then
            echo "[$(date +%H:%M:%S)] Nueva version disponible: $NEW_VERSION"

            # Download AppImage
            echo "[$(date +%H:%M:%S)] Descargando actualizacion..."
            curl -s "$SERVER_URL/api/updates/file/BioLab-LABSYNC-$NEW_VERSION-linux.AppImage" -o "$APPIMAGE_PATH.new"

            if [ -f "$APPIMAGE_PATH.new" ]; then
                chmod +x "$APPIMAGE_PATH.new"

                # Kill running instance
                pkill -f "BioLab-LABSYNC.AppImage" 2>/dev/null || true
                sleep 2

                # Replace old version
                mv "$APPIMAGE_PATH.new" "$APPIMAGE_PATH"

                # Save new version
                echo "$NEW_VERSION" > "$INSTALL_DIR/version.txt"
                CURRENT_VERSION="$NEW_VERSION"

                echo "[$(date +%H:%M:%S)] Actualizacion instalada: $NEW_VERSION"

                # Restart app
                nohup "$APPIMAGE_PATH" &>/dev/null &
            fi
        fi
    else
        echo "[$(date +%H:%M:%S)] La aplicacion esta actualizada (v$CURRENT_VERSION)"
    fi
}

# Main loop
while true; do
    check_and_update
    echo "[$(date +%H:%M:%S)] Proxima verificacion en $((CHECK_INTERVAL / 60)) minutos..."
    echo ""
    sleep $CHECK_INTERVAL
done
