#!/bin/bash
set -e

PLATFORM="${1:-windows}"
MODE="${2:-build}"

if [ -z "$LICENSE_GITHUB_TOKEN" ]; then
  read -p "Ingresa el token de GitHub (LICENSE_GITHUB_TOKEN): " TOKEN
  LICENSE_GITHUB_TOKEN="${TOKEN}"
fi

if [ -z "$LICENSE_GITHUB_TOKEN" ]; then
  echo "ERROR: Token requerido. Configura la variable de entorno LICENSE_GITHUB_TOKEN"
  exit 1
fi

case "$PLATFORM" in
  windows) FLAGS="-d windows" ;;
  macos)   FLAGS="-d macos" ;;
  linux)   FLAGS="-d linux" ;;
  android) FLAGS="-d android" ;;
  ios)     FLAGS="-d ios" ;;
  web)     FLAGS="-d web" ;;
  *)       FLAGS="-d windows" ;;
esac

if [ "$MODE" = "run" ]; then
  echo "Ejecutando en $PLATFORM..."
  flutter run $FLAGS --dart-define=LICENSE_GITHUB_TOKEN=$LICENSE_GITHUB_TOKEN
else
  echo "Compilando para $PLATFORM..."
  flutter build $FLAGS --dart-define=LICENSE_GITHUB_TOKEN=$LICENSE_GITHUB_TOKEN
fi
