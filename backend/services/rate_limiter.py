from collections import defaultdict
from datetime import datetime, timedelta
from fastapi import HTTPException, Request
from typing import Dict, List, Tuple

class SimpleRateLimiter:
    def __init__(self, max_requests: int = 60, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window_seconds = window_seconds
        self.clients: Dict[str, List[datetime]] = defaultdict(list)

    def check(self, request: Request):
        client_ip = request.client.host if request.client else "unknown"
        now = datetime.utcnow()
        window_start = now - timedelta(seconds=self.window_seconds)
        self.clients[client_ip] = [t for t in self.clients[client_ip] if t > window_start]
        if len(self.clients[client_ip]) >= self.max_requests:
            raise HTTPException(status_code=429, detail="Demasiadas solicitudes. Intente de nuevo mas tarde.")
        self.clients[client_ip].append(now)

rate_limiter = SimpleRateLimiter()
