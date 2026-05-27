from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import or_
from pydantic import BaseModel
from typing import Any, Optional
import json
from datetime import datetime

import models
from database import get_db

router = APIRouter(tags=["Audit"])


def _serialize_log(log: models.AuditLog) -> dict:
    """Convert an AuditLog ORM row to a JSON-serialisable dict."""
    try:
        details = json.loads(log.details_json) if log.details_json else {}
    except Exception:
        details = {}
    try:
        changed_fields = json.loads(log.changed_fields_json) if log.changed_fields_json else []
    except Exception:
        changed_fields = []

    return {
        "id": log.id,
        "action": log.action,
        "user_id": log.user_id,
        "device_id": log.device_id,
        "timestamp": log.timestamp.isoformat() if log.timestamp else None,
        "details": details,
        "entity_id": log.entity_id,
        "changed_fields": changed_fields,
        "has_diff": bool(changed_fields),
    }


# ---------------------------------------------------------------------------
# Standard audit log list
# ---------------------------------------------------------------------------

@router.get("/api/audit")
def get_audit_logs(
    limit: int = 100,
    action: Optional[str] = None,
    user_id: Optional[str] = None,
    db: Session = Depends(get_db),
):
    query = db.query(models.AuditLog).order_by(models.AuditLog.timestamp.desc())
    if action:
        query = query.filter(models.AuditLog.action == action.upper())
    if user_id:
        query = query.filter(models.AuditLog.user_id == user_id)
    logs = query.limit(limit).all()
    return [_serialize_log(log) for log in logs]


# ---------------------------------------------------------------------------
# Entity-specific history (all changes to one form entry)
# ---------------------------------------------------------------------------

@router.get("/api/audit/entity/{entity_id}")
def get_entity_history(entity_id: str, db: Session = Depends(get_db)):
    """Returns the full audit trail for a specific form entry or record."""
    logs = (
        db.query(models.AuditLog)
        .filter(models.AuditLog.entity_id == entity_id)
        .order_by(models.AuditLog.timestamp.desc())
        .all()
    )
    return {
        "entity_id": entity_id,
        "total_events": len(logs),
        "history": [_serialize_log(log) for log in logs],
    }


# ---------------------------------------------------------------------------
# Field-diff-only logs (entries that have granular changes)
# ---------------------------------------------------------------------------

@router.get("/api/audit/diffs")
def get_diff_logs(
    limit: int = 200,
    action: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """Returns only audit entries that contain granular field-level diff data."""
    query = (
        db.query(models.AuditLog)
        .filter(
            models.AuditLog.changed_fields_json.isnot(None),
            models.AuditLog.changed_fields_json != "[]",
            models.AuditLog.changed_fields_json != "",
        )
        .order_by(models.AuditLog.timestamp.desc())
    )
    if action:
        query = query.filter(models.AuditLog.action == action.upper())
    logs = query.limit(limit).all()
    return [_serialize_log(log) for log in logs]


# ---------------------------------------------------------------------------
# Write a new granular audit log (from backend actions)
# ---------------------------------------------------------------------------

class AuditWriteRequest(BaseModel):
    action: str
    user_id: Optional[str] = None
    device_id: Optional[str] = None
    entity_id: Optional[str] = None
    details: dict = {}
    changed_fields: list[dict[str, Any]] = []


@router.post("/api/audit")
def write_audit_log(payload: AuditWriteRequest, db: Session = Depends(get_db)):
    now = datetime.utcnow()
    log = models.AuditLog(
        id=f"audit-{now.timestamp()}-{hash(str(payload.dict())) % 9999:04d}",
        action=payload.action.upper(),
        user_id=payload.user_id,
        device_id=payload.device_id,
        timestamp=now,
        details_json=json.dumps(payload.details),
        entity_id=payload.entity_id,
        changed_fields_json=json.dumps(payload.changed_fields),
    )
    db.add(log)
    db.commit()
    return {"success": True, "id": log.id}


# ---------------------------------------------------------------------------
# Aggregate stats for the admin dashboard
# ---------------------------------------------------------------------------

@router.get("/api/audit/stats")
def get_audit_stats(db: Session = Depends(get_db)):
    total = db.query(models.AuditLog).count()
    with_diff = db.query(models.AuditLog).filter(
        models.AuditLog.changed_fields_json.isnot(None),
        models.AuditLog.changed_fields_json != "[]",
        models.AuditLog.changed_fields_json != "",
    ).count()

    # Action breakdown
    from sqlalchemy import func as sa_func
    action_rows = (
        db.query(models.AuditLog.action, sa_func.count(models.AuditLog.id))
        .group_by(models.AuditLog.action)
        .all()
    )
    action_breakdown = {row[0]: row[1] for row in action_rows}

    # Most active users
    user_rows = (
        db.query(models.AuditLog.user_id, sa_func.count(models.AuditLog.id))
        .filter(models.AuditLog.user_id.isnot(None))
        .group_by(models.AuditLog.user_id)
        .order_by(sa_func.count(models.AuditLog.id).desc())
        .limit(10)
        .all()
    )
    most_active_users = [{"user_id": row[0], "events": row[1]} for row in user_rows]

    return {
        "total_events": total,
        "events_with_field_diff": with_diff,
        "action_breakdown": action_breakdown,
        "most_active_users": most_active_users,
    }
