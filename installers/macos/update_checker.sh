#!/bin/bash
# BioLab LABSYNC - Background Update Checker for macOS
# Runs on startup, checks for updates every 30 minutes
# Auto-downloads and installs if update is available

SERVER_URL=${1:-"http://localhost:8000"}
CHECK_INTERVAL=1800  # 30 minutes
APP_PATH="/Applications/BioLab LABSYNC.app"
CURRENT_VERSION="7.1.0"

echo "========================================"
echo "BioLab LABSYNC - Update Checker"
echo "========================================"
echo ""
echo "[INFO] Server: $SERVER_URL"
echo "[INFO] Check interval: $((CHECK_INTERVAL / 60)) minutes"
echo "[INFO] App path: $APP_PATH"
echo ""

check_and_update() {
    # Check for updates
    RESPONSE=$(curl -s "$SERVER_URL/api/updates/check?current_version=$CURRENT_VERSION&platform=macos")

    HAS_UPDATE=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['has_update'])" 2>/dev/null || echo "false")

    if [ "$HAS_UPDATE" = "True" ]; then
        NEW_VERSION=$(echo "$RESPONSE" | python3 -c "import sys,json; print(json.load(sys.stdin)['latest_version'])" 2>/dev/null || echo "")

        if [ -n "$NEW_VERSION" ]; then
            echo "[$(date +%H:%M:%S)] Nueva version disponible: $NEW_VERSION"

            # Download DMG
            echo "[$(date +%H:%M:%S)] Descargando actualizacion..."
            curl -s "$SERVER_URL/api/updates/file/BioLab-LABSYNC-$NEW_VERSION-macos.dmg" -o /tmp/biolab_update.dmg

            if [ -f /tmp/biolab_update.dmg ]; then
                # Kill running instance
                pkill -f "BioLab LABSYNC" 2>/dev/null || true
                sleep 2

                # Mount and install
                MOUNT_POINT=$(hdiutil attach /tmp/biolab_update.dmg -nobrowse -quiet | tail -n 1 | awk '{print $NF}')

                if [ -d "$MOUNT_POINT/BioLab LABSYNC.app" ]; then
                    cp -R "$MOUNT_POINT/BioLab LABSYNC.app" /Applications/
                    hdiutil detach "$MOUNT_POINT" -quiet
                fi

                CURRENT_VERSION="$NEW_VERSION"
                echo "[$(date +%H:%M:%S)] Actualizacion instalada: $NEW_VERSION"

                # Restart app
                open "$APP_PATH"

                # Cleanup
                rm -f /tmp/biolab_update.dmg
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
