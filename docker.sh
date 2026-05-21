#!/bin/bash
set -e

echo "=== BioLab LABSYNC - Docker Build ==="

case "$1" in
  build)
    echo "Building Docker image..."
    docker build -t biolab-labsync:latest .
    echo "Done! Run with: docker compose up -d"
    ;;
  run)
    echo "Starting BioLab LABSYNC on http://localhost:8080..."
    docker compose up -d
    echo "App running at http://localhost:8080"
    ;;
  stop)
    echo "Stopping..."
    docker compose down
    ;;
  rebuild)
    echo "Rebuilding..."
    docker compose down
    docker build -t biolab-labsync:latest .
    docker compose up -d --force-recreate
    echo "Done! App running at http://localhost:8080"
    ;;
  logs)
    docker compose logs -f
    ;;
  *)
    echo "Usage: $0 {build|run|stop|rebuild|logs}"
    echo ""
    echo "  build   - Build Docker image"
    echo "  run     - Start app on port 8080"
    echo "  stop    - Stop running containers"
    echo "  rebuild - Rebuild and restart"
    echo "  logs    - View container logs"
    exit 1
    ;;
esac
