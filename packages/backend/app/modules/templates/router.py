import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.models.template import Template
from app.models.form_entry import FormEntry
from app.schemas.templates import TemplateResponse

router = APIRouter(prefix="/api", tags=["Templates"])

TEMPLATES_SEED = [
    {
        "id": "tpl-incubadoras",
        "name": "Bitacora de Incubadoras",
        "module": "incubadoras",
        "version": 1,
        "fields": [
            {"key": "temperatura", "label": "Temperatura (C)", "type": "number", "required": True, "min": 30, "max": 45},
            {"key": "humedad", "label": "Humedad (%)", "type": "number", "required": True, "min": 0, "max": 100},
            {"key": "co2", "label": "CO2 (%)", "type": "number", "required": False},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
            {"key": "firma", "label": "Firma del Tecnico", "type": "signature", "required": True},
        ],
    },
    {
        "id": "tpl-autoclaves",
        "name": "Control de Autoclave",
        "module": "autoclaves",
        "version": 1,
        "fields": [
            {"key": "temperatura", "label": "Temperatura (C)", "type": "number", "required": True},
            {"key": "presion", "label": "Presion (psi)", "type": "number", "required": True},
            {"key": "tiempo", "label": "Tiempo (min)", "type": "number", "required": True},
            {"key": "ciclo", "label": "Tipo de Ciclo", "type": "select", "required": True, "options": ["Liquidos", "Instrumentos", "Residuos", "Rapido"]},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        ],
    },
    {
        "id": "tpl-ultracongeladores",
        "name": "Registro de Ultracongeladores",
        "module": "ultracongeladores",
        "version": 1,
        "fields": [
            {"key": "temperatura", "label": "Temperatura (C)", "type": "number", "required": True, "min": -90, "max": -60},
            {"key": "alarma", "label": "Estado de Alarma", "type": "select", "required": True, "options": ["Normal", "Alerta", "Critico"]},
            {"key": "respaldo_co2", "label": "Respaldo CO2", "type": "select", "required": True, "options": ["OK", "Bajo", "Vacio"]},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        ],
    },
    {
        "id": "tpl-equipos",
        "name": "Bitacora de Equipos",
        "module": "equipos",
        "version": 1,
        "fields": [
            {"key": "equipo", "label": "Nombre del Equipo", "type": "text", "required": True},
            {"key": "estado", "label": "Estado", "type": "select", "required": True, "options": ["Operativo", "En Mantenimiento", "Fuera de Servicio"]},
            {"key": "horas_uso", "label": "Horas de Uso", "type": "number", "required": False},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        ],
    },
    {
        "id": "tpl-procesamiento",
        "name": "Control de Procesamiento",
        "module": "procesamiento",
        "version": 1,
        "fields": [
            {"key": "tipo_muestra", "label": "Tipo de Muestra", "type": "text", "required": True},
            {"key": "cantidad", "label": "Cantidad", "type": "number", "required": True},
            {"key": "proceso", "label": "Proceso Realizado", "type": "select", "required": True, "options": ["Centrifugacion", "Incubacion", "Esterilizacion", "Almacenamiento"]},
            {"key": "responsable", "label": "Responsable", "type": "text", "required": True},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        ],
    },
]


async def seed_templates(db: AsyncSession):
    result = await db.execute(select(Template))
    if result.first() is None:
        for tpl in TEMPLATES_SEED:
            template = Template(
                id=tpl["id"],
                name=tpl["name"],
                module=tpl["module"],
                version=tpl["version"],
                structure_json=json.dumps(tpl),
            )
            db.add(template)
        await db.commit()
        print(f"Plantillas seeded: {len(TEMPLATES_SEED)} templates")


@router.get("/templates")
async def list_templates(db: AsyncSession = Depends(get_session)):
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
async def get_template(template_id: str, db: AsyncSession = Depends(get_session)):
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


@router.post("/form-entries")
async def save_form_entry(payload: dict, db: AsyncSession = Depends(get_session)):
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
    module: str = None,
    date: str = None,
    db: AsyncSession = Depends(get_session),
):
    query = select(FormEntry)
    if module:
        query = query.where(FormEntry.module == module)
    if date:
        query = query.where(FormEntry.date == date)
    query = query.order_by(FormEntry.date.desc())
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
