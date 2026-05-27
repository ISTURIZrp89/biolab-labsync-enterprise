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
                entry_date_str = item.data.get("date", "")

                # ── Month-closure lock ──────────────────────────────────────
                # Parse the entry date to extract year/month and check whether
                # this month has been administratively closed. If so, reject
                # the upload without processing it.
                if entry_date_str:
                    try:
                        ed = datetime.fromisoformat(entry_date_str)
                        month_lock = db.query(models.MonthClosure).filter(
                            models.MonthClosure.year == ed.year,
                            models.MonthClosure.month == ed.month,
                            models.MonthClosure.status == "CERRADO",
                        ).first()
                        if month_lock:
                            conflicts.append({
                                "entity": "form_entries",
                                "entity_id": item.entity_id,
                                "rejected": True,
                                "reason": f"El mes {ed.year}-{ed.month:02d} está cerrado administrativamente. "
                                          f"Cierre realizado por: {month_lock.closed_by}",
                                "timestamp": server_now.isoformat(),
                            })
                            continue  # Skip this item — do NOT process it
                    except (ValueError, AttributeError):
                        pass
                # ────────────────────────────────────────────────────────────

                if not entry:
                    entry = models.FormEntry(
                        id=item.entity_id,
                        module=item.data.get("module"),
                        date=entry_date_str,
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
                            # Compute field-level diff for conflict record
                            try:
                                old_data = json.loads(entry.data_json) if entry.data_json else {}
                                new_data = item.data.get("data", {})
                                changed = [
                                    {"field": k, "old": old_data.get(k), "new": new_data.get(k)}
                                    for k in set(list(old_data.keys()) + list(new_data.keys()))
                                    if json.dumps(old_data.get(k)) != json.dumps(new_data.get(k))
                                    and k not in ("updated_at", "created_at")
                                ]
                            except Exception:
                                changed = []

                            conflicts.append({
                                "entity": "form_entries",
                                "entity_id": item.entity_id,
                                "local_version": entry.version,
                                "incoming_version": incoming_ver,
                                "resolved_by": "version_higher_wins",
                                "changed_fields": changed,
                                "timestamp": server_now.isoformat()
                            })

                            # Persist a granular audit record for this conflict
                            if changed:
                                conflict_audit = models.AuditLog(
                                    id=f"audit-conflict-{server_now.timestamp()}-{item.entity_id[-6:]}",
                                    action="SYNC_CONFLICT_RESOLVED",
                                    user_id=item.data.get("user_id"),
                                    device_id=payload.device_id,
                                    timestamp=server_now,
                                    details_json=json.dumps({
                                        "resolved_by": "version_higher_wins",
                                        "module": item.data.get("module"),
                                        "date": entry_date_str,
                                    }),
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

            elif item.entity == "month_closures":
                closure = db.query(models.MonthClosure).filter(
                    models.MonthClosure.year == item.data.get("year"),
                    models.MonthClosure.month == item.data.get("month")
                ).first()
                if not closure:
                    closure = models.MonthClosure(
                        id=item.entity_id,
                        year=item.data.get("year"),
                        month=item.data.get("month"),
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
                        details_json=json.dumps(item.data.get("details", {})),
                        entity_id=item.data.get("entity_id"),
                        changed_fields_json=json.dumps(item.data.get("changed_fields", []))
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
                "reopen_log": json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
            }
        })

    query_month_closures = db.query(models.MonthClosure)
    if last_sync:
        query_month_closures = query_month_closures.filter(models.MonthClosure.closed_at > last_sync)

    for mc in query_month_closures.all():
        updates_to_pull.append({
            "entity": "month_closures",
            "id": mc.id,
            "data": {
                "id": mc.id,
                "year": mc.year,
                "month": mc.month,
                "status": mc.status,
                "closed_by": mc.closed_by,
                "closed_at": mc.closed_at.isoformat(),
                "notes": mc.notes,
                "reopen_log": json.loads(mc.reopen_log_json) if mc.reopen_log_json else []
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
