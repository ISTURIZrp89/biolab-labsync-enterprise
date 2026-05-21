from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
import json

import models
from database import get_db

router = APIRouter(tags=["Audit"])

@router.get("/api/audit")
def get_audit_logs(limit: int = 100, db: Session = Depends(get_db)):
    logs = db.query(models.AuditLog).order_by(models.AuditLog.timestamp.desc()).limit(limit).all()
    result = []
    for log in logs:
        result.append({
            "id": log.id,
            "action": log.action,
            "user_id": log.user_id,
            "device_id": log.device_id,
            "timestamp": log.timestamp.isoformat(),
            "details": json.loads(log.details_json) if log.details_json else {}
        })
    return result
