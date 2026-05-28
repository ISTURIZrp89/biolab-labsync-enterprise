#!/bin/bash
set -e

PLATFORM="${1:-linux}"
RUN="${2:-}"

echo "Building BioLab LABSYNC for $PLATFORM..."

if [ "$RUN" = "--run" ]; then
    flutter run -d "$PLATFORM"
else
    flutter build "$PLATFORM" --release
fi

echo "Build successful!"
