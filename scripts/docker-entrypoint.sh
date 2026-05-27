#!/bin/bash
set -e

LLAMA_BIN="/app/llama-server"
MODEL_DIR="/app/models"
MODEL_PATH="$MODEL_DIR/model.gguf"

mkdir -p /app/data "$MODEL_DIR"

if [ ! -f "$LLAMA_BIN" ]; then
    echo "[entrypoint] Descargando llama.cpp server Linux..."
    curl -L -o /tmp/llama-server.tar.xz \
        "https://github.com/ggml-org/llama.cpp/releases/download/b9360/llama-b9360-bin-ubuntu-x64.tar.xz"
    tar -xJf /tmp/llama-server.tar.xz -C /tmp/
    cp /tmp/llama.cpp/llama-server "$LLAMA_BIN"
    chmod +x "$LLAMA_BIN"
    rm -rf /tmp/llama*
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "[entrypoint] Descargando modelo por defecto (TinyLlama 1.1B)..."
    curl -L -o "$MODEL_PATH" \
        "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf"
fi

echo "[entrypoint] Iniciando llama.cpp server en puerto $LLAMA_PORT..."
"$LLAMA_BIN" --host 127.0.0.1 --port "$LLAMA_PORT" \
    -m "$MODEL_PATH" -c 2048 -ngl 0 --cont-batching -np 1 &
LLAMA_PID=$!

sleep 2

echo "[entrypoint] Iniciando FastAPI en puerto 8000..."
cd /app/backend
exec uvicorn main:app --host 0.0.0.0 --port 8000
