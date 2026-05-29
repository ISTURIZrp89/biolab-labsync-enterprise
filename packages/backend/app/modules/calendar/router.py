import json
from datetime import datetime, timezone, timedelta, date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.dependencies import get_current_user, require_roles
from app.models.day_closure import DayClosure
from app.models.month_closure import MonthClosure
from app.models.form_entry import FormEntry
from app.models.audit_log import AuditLog
from app.schemas.calendar import DayClosureRequest, DayReopenRequest, MonthClosureRequest, MonthReopenRequest

router = APIRouter(prefix="/api/calendar", tags=["Calendar"])

MODULES = ["incubadoras", "autoclaves", "ultracongeladores", "equipos", "procesamiento"]


async def get_day_status(date_str: str, db: AsyncSession) -> dict:
    result = await db.execute(select(DayClosure).where(DayClosure.date == date_str))
    closure = result.scalar_one_or_none()
    result = await db.execute(select(FormEntry).where(FormEntry.date == date_str))
    entries = result.scalars().all()

    modules_status = {}
    for m in MODULES:
        module_entries = [e for e in entries if e.module == m]
        if module_entries:
            all_complete = all(e.status == "saved" for e in module_entries)
            modules_status[m] = "COMPLETO" if all_complete else "PENDIENTE"
        else:
            modules_status[m] = "SIN_REGISTRO"

    closure_status = closure.status if closure else "ABIERTO"
    reopen_log = json.loads(closure.reopen_log_json) if closure and closure.reopen_log_json else []

    return {
        "date": date_str,
        "closure_status": closure_status,
        "closed_by": closure.closed_by if closure else None,
        "notes": closure.notes if closure else None,
        "reopen_log": reopen_log,
        "modules": modules_status,
        "overall": closure_status if closure and closure_status not in ("ABIERTO",) else (
            "COMPLETO" if all(s == "COMPLETO" for s in modules_status.values()) else
            "PENDIENTE" if any(s != "SIN_REGISTRO" for s in modules_status.values()) else
            "SIN_REGISTRO"
        ),
    }


@router.get("/month")
async def get_month(
    current_user: dict = Depends(get_current_user),
    year: int = None,
    month: int = None,
    db: AsyncSession = Depends(get_session),
):
    if year is None or month is None:
        now = datetime.now()
        year = year or now.year
        month = month or now.month
    if month < 1 or month > 12:
        raise HTTPException(status_code=400, detail="Mes invalido")
    start = date(year, month, 1)
    end = date(year + 1, 1, 1) if month == 12 else date(year, month + 1, 1)
    days = []
    current = start
    while current < end:
        days.append(await get_day_status(current.isoformat(), db))
        current += timedelta(days=1)
    return {"year": year, "month": month, "days": days}


@router.get("/day/{date_str}")
async def get_day(
    date_str: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    try:
        datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, detail="Formato de fecha invalido")
    return await get_day_status(date_str, db)


@router.post("/close-day")
async def close_day(
    payload: DayClosureRequest,
    current_user: dict = Depends(require_roles("ADMIN", "JEFE")),
    db: AsyncSession = Depends(get_session),
):
    existing = await db.execute(select(DayClosure).where(DayClosure.date == payload.date))
    closure = existing.scalar_one_or_none()

    if closure and closure.status == "CERRADO":
        raise HTTPException(status_code=400, detail="El dia ya esta cerrado")

    if closure:
        closure.status = payload.status
        closure.closed_by = payload.closed_by
        closure.notes = payload.notes
        closure.closed_at = datetime.now(timezone.utc)
    else:
        closure = DayClosure(
            id=f"dc-{payload.date}",
            date=payload.date,
            status=payload.status,
            closed_by=payload.closed_by,
            notes=payload.notes,
            reopen_log_json="[]",
        )
        db.add(closure)

    audit = AuditLog(
        action="CLOSE_DAY",
        user_id=payload.closed_by,
        details_json=json.dumps({"date": payload.date, "status": payload.status, "notes": payload.notes}),
    )
    db.add(audit)
    await db.commit()
    return {"success": True, "date": payload.date, "status": payload.status}


@router.post("/reopen-day")
async def reopen_day(
    payload: DayReopenRequest,
    current_user: dict = Depends(require_roles("ADMIN", "JEFE")),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(DayClosure).where(DayClosure.date == payload.date))
    closure = result.scalar_one_or_none()
    if not closure:
        raise HTTPException(status_code=404, detail="No hay cierre para esta fecha")

    reopen_log = json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
    reopen_log.append({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "reopened_by": payload.reopened_by,
        "reason": payload.reason,
    })
    closure.status = "REABIERTO"
    closure.reopen_log_json = json.dumps(reopen_log)
    closure.notes = f"Reabierto: {payload.reason}"

    audit = AuditLog(
        action="REOPEN_DAY",
        user_id=payload.reopened_by,
        details_json=json.dumps({"date": payload.date, "reason": payload.reason}),
    )
    db.add(audit)
    await db.commit()
    return {"success": True, "date": payload.date, "status": "REABIERTO"}


@router.post("/close-month")
async def close_month(
    payload: MonthClosureRequest,
    current_user: dict = Depends(require_roles("ADMIN", "JEFE")),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(MonthClosure).where(
            MonthClosure.year == payload.year,
            MonthClosure.month == payload.month,
        )
    )
    closure = result.scalar_one_or_none()
    if closure and closure.status == "CERRADO":
        raise HTTPException(status_code=400, detail="El mes ya esta cerrado")

    if closure:
        closure.status = payload.status
        closure.closed_by = payload.closed_by
        closure.notes = payload.notes
        closure.closed_at = datetime.now(timezone.utc)
    else:
        closure = MonthClosure(
            id=f"mc-{payload.year}-{payload.month:02d}",
            year=payload.year,
            month=payload.month,
            status=payload.status,
            closed_by=payload.closed_by,
            notes=payload.notes,
            reopen_log_json="[]",
        )
        db.add(closure)

    audit = AuditLog(
        action="CLOSE_MONTH",
        user_id=payload.closed_by,
        details_json=json.dumps({"year": payload.year, "month": payload.month, "status": payload.status}),
    )
    db.add(audit)
    await db.commit()
    return {"success": True, "year": payload.year, "month": payload.month, "status": payload.status}


@router.post("/reopen-month")
async def reopen_month(
    payload: MonthReopenRequest,
    current_user: dict = Depends(require_roles("ADMIN", "JEFE")),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(MonthClosure).where(
            MonthClosure.year == payload.year,
            MonthClosure.month == payload.month,
        )
    )
    closure = result.scalar_one_or_none()
    if not closure:
        raise HTTPException(status_code=404, detail="No hay cierre para esta fecha")

    reopen_log = json.loads(closure.reopen_log_json) if closure.reopen_log_json else []
    reopen_log.append({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "reopened_by": payload.reopened_by,
        "reason": payload.reason,
    })
    closure.status = "REABIERTO"
    closure.reopen_log_json = json.dumps(reopen_log)
    closure.notes = f"Reabierto: {payload.reason}"

    audit = AuditLog(
        action="REOPEN_MONTH",
        user_id=payload.reopened_by,
        details_json=json.dumps({"year": payload.year, "month": payload.month, "reason": payload.reason}),
    )
    db.add(audit)
    await db.commit()
    return {"success": True, "year": payload.year, "month": payload.month, "status": "REABIERTO"}


@router.get("/month-status/{year}/{month}")
async def get_month_status(
    year: int,
    month: int,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(MonthClosure).where(
            MonthClosure.year == year,
            MonthClosure.month == month,
        )
    )
    closure = result.scalar_one_or_none()
    return {
        "year": year,
        "month": month,
        "status": closure.status if closure else "ABIERTO",
        "closed_by": closure.closed_by if closure else None,
        "closed_at": closure.closed_at.isoformat() if closure and closure.closed_at else None,
        "notes": closure.notes if closure else None,
        "reopen_log": json.loads(closure.reopen_log_json) if closure and closure.reopen_log_json else [],
    }
