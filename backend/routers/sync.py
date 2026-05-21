from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
import json

import models, schemas
from database import get_db

router = APIRouter(tags=["Sync"])

@router.post("/api/sync", response_model=schemas.SyncResponse)
def sync_data(payload: schemas.SyncPayload, db: Session = Depends(get_db)):
    device = db.query(models.Device).filter(models.Device.id == payload.device_id).first()
    if not device:
        raise HTTPException(status_code=400, detail="Dispositivo no registrado")

    processed_ids = []
    conflicts = []
    server_now = datetime.utcnow()

    for item in payload.queue:
        try:
            if item.entity == "form_entries":
                entry = db.query(models.FormEntry).filter(models.FormEntry.id == item.entity_id).first()
                incoming_ver = item.data.get("version", 1)

                if not entry:
                    entry = models.FormEntry(
                        id=item.entity_id,
                        module=item.data.get("module"),
                        date=item.data.get("date"),
                        user_id=item.data.get("user_id"),
                        device_id=payload.device_id,
                        version=incoming_ver,
                        data_json=json.dumps(item.data.get("data", {})),
                        status=item.data.get("status", "saved")
                    )
                    db.add(entry)
                else:
                    if incoming_ver > entry.version:
                        if entry.device_id != payload.device_id:
                            conflicts.append({
                                "entity": "form_entries",
                                "entity_id": item.entity_id,
                                "local_version": entry.version,
                                "incoming_version": incoming_ver,
                                "resolved_by": "version_higher_wins",
                                "timestamp": server_now.isoformat()
                            })
                        entry.version = incoming_ver
                        entry.data_json = json.dumps(item.data.get("data", {}))
                        entry.status = item.data.get("status", "saved")
                        entry.user_id = item.data.get("user_id")
                        entry.device_id = payload.device_id
                        entry.updated_at = server_now

                db.commit()
                processed_ids.append(item.id)

            elif item.entity == "day_closures":
                closure = db.query(models.DayClosure).filter(models.DayClosure.date == item.data.get("date")).first()
                if not closure:
                    closure = models.DayClosure(
                        id=item.entity_id,
                        date=item.data.get("date"),
                        status=item.data.get("status"),
                        closed_by=item.data.get("closed_by"),
                        notes=item.data.get("notes"),
                        reopen_log_json=json.dumps(item.data.get("reopen_log", []))
                    )
                    db.add(closure)
                else:
                    local_log = json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
                    incoming_log = item.data.get("reopen_log", [])
                    merged_log = {x["timestamp"]: x for x in local_log + incoming_log}.values()
                    closure.reopen_log_json = json.dumps(list(merged_log))
                    closure.status = item.data.get("status")
                    closure.notes = item.data.get("notes")
                    closure.closed_by = item.data.get("closed_by")
                    closure.closed_at = server_now

                db.commit()
                processed_ids.append(item.id)

            elif item.entity == "audit_logs":
                log = db.query(models.AuditLog).filter(models.AuditLog.id == item.entity_id).first()
                if not log:
                    log = models.AuditLog(
                        id=item.entity_id,
                        action=item.data.get("action"),
                        user_id=item.data.get("user_id"),
                        device_id=payload.device_id,
                        timestamp=datetime.fromisoformat(item.data.get("timestamp").replace("Z", "+00:00")),
                        details_json=json.dumps(item.data.get("details", {}))
                    )
                    db.add(log)
                    db.commit()
                processed_ids.append(item.id)

        except Exception as ex:
            db.rollback()
            print(f"Error procesando item de sincronizacion {item.id}: {ex}")

    updates_to_pull = []
    last_sync = None
    if payload.last_sync_timestamp:
        try:
            last_sync = datetime.fromisoformat(payload.last_sync_timestamp.replace("Z", "+00:00"))
        except:
            pass

    query_entries = db.query(models.FormEntry)
    if last_sync:
        query_entries = query_entries.filter(models.FormEntry.updated_at > last_sync)
    query_entries = query_entries.filter(models.FormEntry.device_id != payload.device_id)

    for entry in query_entries.all():
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
                "created_at": entry.created_at.isoformat(),
                "updated_at": entry.updated_at.isoformat()
            }
        })

    query_closures = db.query(models.DayClosure)
    if last_sync:
        query_closures = query_closures.filter(models.DayClosure.closed_at > last_sync)

    for closure in query_closures.all():
        updates_to_pull.append({
            "entity": "day_closures",
            "id": closure.id,
            "data": {
                "id": closure.id,
                "date": closure.date,
                "status": closure.status,
                "closed_by": closure.closed_by,
                "closed_at": closure.closed_at.isoformat(),
                "notes": closure.notes,
                "reopen_log": json.loads(closure.reopen_log_json)
            }
        })

    audit = models.AuditLog(
        id=f"audit-sync-{server_now.timestamp()}",
        action="SYNC",
        device_id=payload.device_id,
        details_json=json.dumps({
            "uploaded": len(processed_ids),
            "downloaded": len(updates_to_pull),
            "conflicts": len(conflicts)
        })
    )
    db.add(audit)

    sync_record = models.SyncHistory(
        id=f"sh-{server_now.timestamp()}",
        device_id=payload.device_id,
        records_uploaded=len(processed_ids),
        records_downloaded=len(updates_to_pull),
        status="success"
    )
    db.add(sync_record)
    db.commit()

    return {
        "success": True,
        "processed_ids": processed_ids,
        "updates_to_pull": updates_to_pull,
        "conflicts": conflicts,
        "server_time": server_now.isoformat()
    }

@router.get("/api/sync/status")
def get_sync_status(limit: int = 20, db: Session = Depends(get_db)):
    history = db.query(models.SyncHistory).order_by(models.SyncHistory.synced_at.desc()).limit(limit).all()
    return [
        {
            "id": h.id,
            "device_id": h.device_id,
            "synced_at": h.synced_at.isoformat(),
            "uploaded": h.records_uploaded,
            "downloaded": h.records_downloaded,
            "status": h.status
        }
        for h in history
    ]
