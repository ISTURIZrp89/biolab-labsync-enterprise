from datetime import datetime, timedelta, timezone


class RateLimiter:
    def __init__(self, max_requests: int = 60, window_seconds: int = 60):
        self.max_requests = max_requests
        self.window = timedelta(seconds=window_seconds)
        self._requests: dict[str, list[datetime]] = {}

    def is_allowed(self, key: str) -> bool:
        now = datetime.now(timezone.utc)
        if key not in self._requests:
            self._requests[key] = []
        self._requests[key] = [t for t in self._requests[key] if now - t < self.window]
        if len(self._requests[key]) >= self.max_requests:
            return False
        self._requests[key].append(now)
        return True
