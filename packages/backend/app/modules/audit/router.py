import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.dependencies import get_current_user
from app.models.audit_log import AuditLog
from app.schemas.audit import AuditWriteRequest

router = APIRouter(prefix="/api/audit", tags=["Audit"])


def _serialize_log(log: AuditLog) -> dict:
    details = {}
    changed_fields = []
    try:
        details = json.loads(log.details_json) if log.details_json else {}
    except Exception:
        pass
    try:
        changed_fields = json.loads(log.changed_fields_json) if log.changed_fields_json else []
    except Exception:
        pass
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


@router.get("")
async def get_audit_logs(
    current_user: dict = Depends(get_current_user),
    skip: int = 0,
    limit: int = 100,
    action: str = None,
    user_id: str = None,
    db: AsyncSession = Depends(get_session),
):
    query = select(AuditLog).order_by(AuditLog.timestamp.desc())
    if action:
        query = query.where(AuditLog.action == action.upper())
    if user_id:
        query = query.where(AuditLog.user_id == user_id)
    query = query.offset(skip).limit(limit)
    result = await db.execute(query)
    return [_serialize_log(log) for log in result.scalars().all()]


@router.get("/entity/{entity_id}")
async def get_entity_history(
    entity_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(AuditLog)
        .where(AuditLog.entity_id == entity_id)
        .order_by(AuditLog.timestamp.desc())
    )
    logs = result.scalars().all()
    return {"entity_id": entity_id, "total_events": len(logs), "history": [_serialize_log(log) for log in logs]}


@router.get("/diffs")
async def get_diff_logs(
    current_user: dict = Depends(get_current_user),
    limit: int = 200,
    action: str = None,
    db: AsyncSession = Depends(get_session),
):
    query = select(AuditLog).where(
        AuditLog.changed_fields_json.isnot(None),
        AuditLog.changed_fields_json != "[]",
        AuditLog.changed_fields_json != "",
    ).order_by(AuditLog.timestamp.desc())
    if action:
        query = query.where(AuditLog.action == action.upper())
    query = query.limit(limit)
    result = await db.execute(query)
    return [_serialize_log(log) for log in result.scalars().all()]


@router.post("")
async def write_audit_log(
    payload: AuditWriteRequest,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    log = AuditLog(
        action=payload.action.upper(),
        user_id=payload.user_id,
        device_id=payload.device_id,
        details_json=json.dumps(payload.details),
        entity_id=payload.entity_id,
        changed_fields_json=json.dumps(payload.changed_fields),
    )
    db.add(log)
    await db.commit()
    return {"success": True, "id": log.id}


@router.get("/stats")
async def get_audit_stats(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(func.count(AuditLog.id)))
    total = result.scalar()

    result = await db.execute(
        select(func.count(AuditLog.id)).where(
            AuditLog.changed_fields_json.isnot(None),
            AuditLog.changed_fields_json != "[]",
            AuditLog.changed_fields_json != "",
        )
    )
    with_diff = result.scalar()

    result = await db.execute(
        select(AuditLog.action, func.count(AuditLog.id)).group_by(AuditLog.action)
    )
    action_breakdown = {row[0]: row[1] for row in result.all()}

    result = await db.execute(
        select(AuditLog.user_id, func.count(AuditLog.id))
        .where(AuditLog.user_id.isnot(None))
        .group_by(AuditLog.user_id)
        .order_by(func.count(AuditLog.id).desc())
        .limit(10)
    )
    most_active_users = [{"user_id": row[0], "events": row[1]} for row in result.all()]

    return {
        "total_events": total,
        "events_with_field_diff": with_diff,
        "action_breakdown": action_breakdown,
        "most_active_users": most_active_users,
    }
