import json
import logging
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, WebSocket
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.dependencies import get_current_user
from app.models.audit_log import AuditLog
from app.models.day_closure import DayClosure
from app.models.device import Device
from app.models.form_entry import FormEntry
from app.models.month_closure import MonthClosure
from app.models.sync_history import SyncHistory
from app.modules.sync.websocket import sync_websocket
from app.schemas.sync import SyncPayload, SyncResponse

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/sync", tags=["Sync"])


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, device_id: str):
    await sync_websocket(websocket, device_id)


@router.post("", response_model=SyncResponse)
async def sync_data(
    payload: SyncPayload,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(Device).where(Device.id == payload.device_id))
    device = result.scalar_one_or_none()
    if not device:
        raise HTTPException(status_code=400, detail="Dispositivo no registrado")

    processed_ids = []
    conflicts = []
    server_now = datetime.now(timezone.utc)

    for item in payload.queue:
        try:
            if item.entity == "form_entries":
                result = await db.execute(select(FormEntry).where(FormEntry.id == item.entity_id))
                entry = result.scalar_one_or_none()
                incoming_ver = item.data.get("version", 1)
                entry_date_str = item.data.get("date", "")

                if entry_date_str:
                    try:
                        ed = datetime.fromisoformat(entry_date_str)
                        result = await db.execute(
                            select(MonthClosure).where(
                                MonthClosure.year == ed.year,
                                MonthClosure.month == ed.month,
                                MonthClosure.status == "CERRADO",
                            )
                        )
                        month_lock = result.scalar_one_or_none()
                        if month_lock:
                            conflicts.append({
                                "entity": "form_entries",
                                "entity_id": item.entity_id,
                                "rejected": True,
                                "reason": f"El mes {ed.year}-{ed.month:02d} esta cerrado administrativamente",
                                "timestamp": server_now.isoformat(),
                            })
                            continue
                    except (ValueError, AttributeError):
                        pass

                if not entry:
                    entry = FormEntry(
                        id=item.entity_id,
                        module=item.data.get("module"),
                        date=entry_date_str,
                        user_id=item.data.get("user_id"),
                        device_id=payload.device_id,
                        version=incoming_ver,
                        data_json=json.dumps(item.data.get("data", {})),
                        status=item.data.get("status", "saved"),
                    )
                    db.add(entry)
                else:
                    if incoming_ver > entry.version:
                        if entry.device_id != payload.device_id:
                            old_data = json.loads(entry.data_json) if entry.data_json else {}
                            new_data = item.data.get("data", {})
                            changed = [
                                {"field": k, "old": old_data.get(k), "new": new_data.get(k)}
                                for k in set(list(old_data.keys()) + list(new_data.keys()))
                                if json.dumps(old_data.get(k)) != json.dumps(new_data.get(k))
                                and k not in ("updated_at", "created_at")
                            ]
                            conflicts.append({
                                "entity": "form_entries",
                                "entity_id": item.entity_id,
                                "local_version": entry.version,
                                "incoming_version": incoming_ver,
                                "resolved_by": "version_higher_wins",
                                "changed_fields": changed,
                                "timestamp": server_now.isoformat(),
                            })
                            if changed:
                                conflict_audit = AuditLog(
                                    action="SYNC_CONFLICT_RESOLVED",
                                    user_id=item.data.get("user_id"),
                                    device_id=payload.device_id,
                                    timestamp=server_now,
                                    details_json=json.dumps({"resolved_by": "version_higher_wins"}),
                                    entity_id=item.entity_id,
                                    changed_fields_json=json.dumps(changed),
                                )
                                db.add(conflict_audit)
                        entry.version = incoming_ver
                        entry.data_json = json.dumps(item.data.get("data", {}))
                        entry.status = item.data.get("status", "saved")
                        entry.user_id = item.data.get("user_id")
                        entry.device_id = payload.device_id
                        entry.updated_at = server_now
                await db.flush()
                processed_ids.append(item.id)

            elif item.entity == "day_closures":
                result = await db.execute(select(DayClosure).where(DayClosure.date == item.data.get("date")))
                closure = result.scalar_one_or_none()
                if not closure:
                    closure = DayClosure(
                        id=item.entity_id,
                        date=item.data.get("date"),
                        status=item.data.get("status"),
                        closed_by=item.data.get("closed_by"),
                        notes=item.data.get("notes"),
                        reopen_log_json=json.dumps(item.data.get("reopen_log", [])),
                    )
                    db.add(closure)
                else:
                    local_log = json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
                    incoming_log = item.data.get("reopen_log", [])
                    merged = {x["timestamp"]: x for x in local_log + incoming_log}.values()
                    closure.reopen_log_json = json.dumps(list(merged))
                    closure.status = item.data.get("status", closure.status)
                    closure.notes = item.data.get("notes", closure.notes)
                    closure.closed_by = item.data.get("closed_by", closure.closed_by)
                    closure.closed_at = server_now
                await db.flush()
                processed_ids.append(item.id)

            elif item.entity == "month_closures":
                result = await db.execute(
                    select(MonthClosure).where(
                        MonthClosure.year == item.data.get("year"),
                        MonthClosure.month == item.data.get("month"),
                    )
                )
                closure = result.scalar_one_or_none()
                if not closure:
                    closure = MonthClosure(
                        id=item.entity_id,
                        year=item.data.get("year"),
                        month=item.data.get("month"),
                        status=item.data.get("status"),
                        closed_by=item.data.get("closed_by"),
                        notes=item.data.get("notes"),
                        reopen_log_json=json.dumps(item.data.get("reopen_log", [])),
                    )
                    db.add(closure)
                else:
                    local_log = json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
                    incoming_log = item.data.get("reopen_log", [])
                    merged = {x["timestamp"]: x for x in local_log + incoming_log}.values()
                    closure.reopen_log_json = json.dumps(list(merged))
                    closure.status = item.data.get("status", closure.status)
                    closure.notes = item.data.get("notes", closure.notes)
                    closure.closed_by = item.data.get("closed_by", closure.closed_by)
                    closure.closed_at = server_now
                await db.flush()
                processed_ids.append(item.id)

            elif item.entity == "audit_logs":
                result = await db.execute(select(AuditLog).where(AuditLog.id == item.entity_id))
                log = result.scalar_one_or_none()
                if not log:
                    log = AuditLog(
                        id=item.entity_id,
                        action=item.data.get("action"),
                        user_id=item.data.get("user_id"),
                        device_id=payload.device_id,
                        timestamp=datetime.fromisoformat(item.data.get("timestamp", server_now.isoformat()).replace("Z", "+00:00")),
                        details_json=json.dumps(item.data.get("details", {})),
                        entity_id=item.data.get("entity_id"),
                        changed_fields_json=json.dumps(item.data.get("changed_fields", [])),
                    )
                    db.add(log)
                    await db.flush()
                processed_ids.append(item.id)

        except Exception as ex:
            logger.error("Error procesando item %s: %s", item.id, ex)

    await db.commit()

    updates_to_pull = []
    last_sync = None
    if payload.last_sync_timestamp:
        try:
            last_sync = datetime.fromisoformat(payload.last_sync_timestamp.replace("Z", "+00:00"))
        except Exception:
            pass

    query = select(FormEntry)
    if last_sync:
        query = query.where(FormEntry.updated_at > last_sync)
    query = query.where(FormEntry.device_id != payload.device_id)
    query = query.limit(500)
    result = await db.execute(query)
    for entry in result.scalars().all():
        updates_to_pull.append({
            "entity": "form_entries",
            "id": entry.id,
            "data": {
                "id": entry.id,
                "module": entry.module,
                "date": entry.date,
                "user_id": entry.user_id,
                "device_id": entry.device_id,
                "version": entry.version,
                "data": json.loads(entry.data_json),
                "status": entry.status,
                "created_at": entry.created_at.isoformat() if entry.created_at else None,
                "updated_at": entry.updated_at.isoformat() if entry.updated_at else None,
            },
        })

    q_closures = select(DayClosure)
    if last_sync:
        q_closures = q_closures.where(DayClosure.closed_at > last_sync)
    q_closures = q_closures.limit(200)
    result = await db.execute(q_closures)
    for closure in result.scalars().all():
        updates_to_pull.append({
            "entity": "day_closures",
            "id": closure.id,
            "data": {
                "id": closure.id,
                "date": closure.date,
                "status": closure.status,
                "closed_by": closure.closed_by,
                "closed_at": closure.closed_at.isoformat() if closure.closed_at else None,
                "notes": closure.notes,
                "reopen_log": json.loads(closure.reopen_log_json) if closure.reopen_log_json else [],
            },
        })

    q_mc = select(MonthClosure)
    if last_sync:
        q_mc = q_mc.where(MonthClosure.closed_at > last_sync)
    q_mc = q_mc.limit(100)
    result = await db.execute(q_mc)
    for mc in result.scalars().all():
        updates_to_pull.append({
            "entity": "month_closures",
            "id": mc.id,
            "data": {
                "id": mc.id,
                "year": mc.year,
                "month": mc.month,
                "status": mc.status,
                "closed_by": mc.closed_by,
                "closed_at": mc.closed_at.isoformat() if mc.closed_at else None,
                "notes": mc.notes,
                "reopen_log": json.loads(mc.reopen_log_json) if mc.reopen_log_json else [],
            },
        })

    audit = AuditLog(
        action="SYNC",
        device_id=payload.device_id,
        details_json=json.dumps({"uploaded": len(processed_ids), "downloaded": len(updates_to_pull), "conflicts": len(conflicts)}),
    )
    db.add(audit)

    sync_record = SyncHistory(
        device_id=payload.device_id,
        records_uploaded=len(processed_ids),
        records_downloaded=len(updates_to_pull),
        status="success",
    )
    db.add(sync_record)
    await db.commit()

    return SyncResponse(
        success=True,
        processed_ids=processed_ids,
        updates_to_pull=updates_to_pull,
        conflicts=conflicts,
        server_time=server_now.isoformat(),
    )


@router.get("/status")
async def get_sync_status(
    current_user: dict = Depends(get_current_user),
    limit: int = 20,
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(SyncHistory).order_by(SyncHistory.synced_at.desc()).limit(min(limit, 100))
    )
    return [
        {
            "id": h.id,
            "device_id": h.device_id,
            "synced_at": h.synced_at.isoformat() if h.synced_at else None,
            "uploaded": h.records_uploaded,
            "downloaded": h.records_downloaded,
            "status": h.status,
        }
        for h in result.scalars().all()
    ]
