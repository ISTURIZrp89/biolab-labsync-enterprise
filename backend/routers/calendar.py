from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta, date
import json
from typing import Optional, Dict, Any
from pydantic import BaseModel

import models
from database import get_db

router = APIRouter(tags=["Calendar"])

MODULES = ["incubadoras", "autoclaves", "ultracongeladores", "equipos", "procesamiento"]

class DayClosureRequest(BaseModel):
    date: str
    status: str
    closed_by: str
    notes: str

class DayReopenRequest(BaseModel):
    date: str
    reopened_by: str
    reason: str

def get_day_status(date_str: str, db: Session) -> dict:
    closure = db.query(models.DayClosure).filter(models.DayClosure.date == date_str).first()
    entries = db.query(models.FormEntry).filter(models.FormEntry.date == date_str).all()
    modules_status = {}
    for m in MODULES:
        module_entries = [e for e in entries if e.module == m]
        if module_entries:
            all_complete = all(e.status == "saved" for e in module_entries)
            modules_status[m] = "COMPLETO" if all_complete else "PENDIENTE"
        else:
            modules_status[m] = "SIN_REGISTRO"
    closure_status = closure.status if closure else "ABIERTO"
    return {
        "date": date_str,
        "closure_status": closure_status,
        "closed_by": closure.closed_by if closure else None,
        "notes": closure.notes if closure else None,
        "reopen_log": json.loads(closure.reopen_log_json) if closure and closure.reopen_log_json else [],
        "modules": modules_status,
        "overall": closure_status if closure and closure_status != "ABIERTO" else (
            "COMPLETO" if all(s == "COMPLETO" for s in modules_status.values()) else
            "PENDIENTE" if any(s != "SIN_REGISTRO" for s in modules_status.values()) else
            "SIN_REGISTRO"
        )
    }

@router.get("/api/calendar/month")
def get_month(year: int, month: int, db: Session = Depends(get_db)):
    start_date = date(year, month, 1)
    if month == 12:
        end_date = date(year + 1, 1, 1)
    else:
        end_date = date(year, month + 1, 1)
    days = []
    current = start_date
    while current < end_date:
        date_str = current.isoformat()
        days.append(get_day_status(date_str, db))
        current += timedelta(days=1)
    return {"year": year, "month": month, "days": days}

@router.get("/api/calendar/day/{date_str}")
def get_day(date_str: str, db: Session = Depends(get_db)):
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except:
        raise HTTPException(status_code=400, detail="Formato de fecha invalido. Use YYYY-MM-DD")
    return get_day_status(date_str, db)

@router.post("/api/calendar/close-day")
def close_day(payload: DayClosureRequest, db: Session = Depends(get_db)):
    try:
        datetime.strptime(payload.date, "%Y-%m-%d")
    except:
        raise HTTPException(status_code=400, detail="Formato de fecha invalido")

    existing = db.query(models.DayClosure).filter(models.DayClosure.date == payload.date).first()
    if existing and existing.status == "CERRADO":
        raise HTTPException(status_code=400, detail="El dia ya esta cerrado. Use reabrir para modificarlo.")

    if existing and existing.status == "CERRADO_CON_OBSERVACION":
        existing.status = payload.status
        existing.closed_by = payload.closed_by
        existing.notes = payload.notes
        existing.closed_at = datetime.utcnow()
    elif existing:
        existing.status = payload.status
        existing.closed_by = payload.closed_by
        existing.notes = payload.notes
        existing.closed_at = datetime.utcnow()
    else:
        closure = models.DayClosure(
            id=f"dc-{payload.date}",
            date=payload.date,
            status=payload.status,
            closed_by=payload.closed_by,
            notes=payload.notes,
            reopen_log_json="[]"
        )
        db.add(closure)

    audit = models.AuditLog(
        id=f"audit-{datetime.utcnow().timestamp()}",
        action="CLOSE_DAY",
        user_id=payload.closed_by,
        details_json=json.dumps({"date": payload.date, "status": payload.status, "notes": payload.notes})
    )
    db.add(audit)
    db.commit()
    return {"success": True, "date": payload.date, "status": payload.status}

@router.post("/api/calendar/reopen-day")
def reopen_day(payload: DayReopenRequest, db: Session = Depends(get_db)):
    closure = db.query(models.DayClosure).filter(models.DayClosure.date == payload.date).first()
    if not closure:
        raise HTTPException(status_code=404, detail="No hay cierre para esta fecha")

    reopen_log = json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
    reopen_log.append({
        "timestamp": datetime.utcnow().isoformat(),
        "reopened_by": payload.reopened_by,
        "reason": payload.reason
    })

    closure.status = "REABIERTO"
    closure.reopen_log_json = json.dumps(reopen_log)
    closure.notes = f"Reabierto: {payload.reason}"

    audit = models.AuditLog(
        id=f"audit-{datetime.utcnow().timestamp()}",
        action="REOPEN_DAY",
        user_id=payload.reopened_by,
        details_json=json.dumps({"date": payload.date, "reason": payload.reason})
    )
    db.add(audit)
    db.commit()
    return {"success": True, "date": payload.date, "status": "REABIERTO"}
