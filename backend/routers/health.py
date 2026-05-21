from fastapi import APIRouter
from datetime import datetime

router = APIRouter(tags=["Health"])

@router.get("/api/health")
def health_check():
    return {
        "status": "ok",
        "server_time": datetime.utcnow().isoformat(),
        "version": "7.0"
    }
