FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    libsqlcipher-dev \
    gcc \
    curl \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt /app/backend/requirements.txt
RUN pip install --no-cache-dir -r /app/backend/requirements.txt

COPY backend/ /app/backend/
ENV PYTHONPATH=/app

COPY frontend_flutter/build/web/ /app/static/

COPY scripts/docker-entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

ENV DATABASE_URL=sqlite:///app/data/labsync.db
ENV SYNC_SERVER_PORT=8000
ENV CORS_ORIGINS=*
ENV LLAMA_PORT=8080

VOLUME ["/app/data"]

EXPOSE 8000

ENTRYPOINT ["/app/entrypoint.sh"]
