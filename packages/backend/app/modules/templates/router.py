import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.dependencies import get_current_user
from app.models.form_entry import FormEntry
from app.models.template import Template

router = APIRouter(prefix="/api", tags=["Templates"])


@router.get("/templates")
async def list_templates(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(Template))
    templates = result.scalars().all()
    output = []
    for t in templates:
        struct = json.loads(t.structure_json)
        output.append({
            "id": t.id,
            "name": struct.get("name", t.name),
            "module": struct.get("module", ""),
            "version": t.version,
            "fields": struct.get("fields", []),
        })
    return output


@router.get("/templates/{template_id}")
async def get_template(
    template_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(Template).where(Template.id == template_id))
    t = result.scalar_one_or_none()
    if not t:
        raise HTTPException(status_code=404, detail="Plantilla no encontrada")
    struct = json.loads(t.structure_json)
    return {
        "id": t.id,
        "name": t.name,
        "module": struct.get("module", ""),
        "version": t.version,
        "fields": struct.get("fields", []),
    }


@router.put("/form-entries/{entry_id}")
async def update_form_entry(
    entry_id: str,
    payload: dict,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(FormEntry).where(FormEntry.id == entry_id))
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entrada no encontrada")

    if "module" in payload:
        entry.module = payload["module"]
    if "date" in payload:
        entry.date = payload["date"]
    if "user_id" in payload:
        entry.user_id = payload["user_id"]
    if "version" in payload:
        entry.version = payload["version"]
    if "data" in payload:
        entry.data_json = json.dumps(payload["data"])
    if "status" in payload:
        entry.status = payload["status"]
    entry.updated_at = datetime.now(timezone.utc)

    await db.commit()
    return {"success": True, "id": entry.id}


@router.delete("/form-entries/{entry_id}")
async def delete_form_entry(
    entry_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(FormEntry).where(FormEntry.id == entry_id))
    entry = result.scalar_one_or_none()
    if not entry:
        raise HTTPException(status_code=404, detail="Entrada no encontrada")

    await db.delete(entry)
    await db.commit()
    return {"success": True, "id": entry_id, "deleted": True}


@router.post("/form-entries")
async def save_form_entry(
    payload: dict,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    entry = FormEntry(
        id=payload.get("id"),
        module=payload.get("module", ""),
        date=payload.get("date", ""),
        user_id=payload.get("user_id", ""),
        device_id=payload.get("device_id", ""),
        version=payload.get("version", 1),
        data_json=json.dumps(payload.get("data", {})),
        status=payload.get("status", "saved"),
    )
    db.add(entry)
    await db.commit()
    return {"success": True, "id": entry.id}


@router.get("/form-entries")
async def get_form_entries(
    current_user: dict = Depends(get_current_user),
    skip: int = 0,
    limit: int = 100,
    module: str = None,
    date: str = None,
    db: AsyncSession = Depends(get_session),
):
    query = select(FormEntry)
    if module:
        query = query.where(FormEntry.module == module)
    if date:
        query = query.where(FormEntry.date == date)
    query = query.order_by(FormEntry.date.desc()).offset(skip).limit(limit)
    result = await db.execute(query)
    entries = result.scalars().all()
    output = []
    for e in entries:
        output.append({
            "id": e.id,
            "module": e.module,
            "date": e.date,
            "user_id": e.user_id,
            "device_id": e.device_id,
            "version": e.version,
            "data": json.loads(e.data_json) if e.data_json else {},
            "status": e.status,
            "created_at": e.created_at.isoformat() if e.created_at else None,
            "updated_at": e.updated_at.isoformat() if e.updated_at else None,
        })
    return output
