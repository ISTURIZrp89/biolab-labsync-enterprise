from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
import json
from typing import List, Dict, Any

import models
from database import get_db

router = APIRouter(tags=["Templates"])

TEMPLATES_SEED = [
    {
        "id": "tpl-incubadoras",
        "name": "Bitacora de Incubadoras",
        "module": "incubadoras",
        "version": 1,
        "fields": [
            {"key": "temperatura", "label": "Temperatura (°C)", "type": "number", "required": True, "min": 30, "max": 45},
            {"key": "humedad", "label": "Humedad (%)", "type": "number", "required": True, "min": 0, "max": 100},
            {"key": "co2", "label": "CO2 (%)", "type": "number", "required": False},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
            {"key": "firma", "label": "Firma del Tecnico", "type": "signature", "required": True},
        ]
    },
    {
        "id": "tpl-autoclaves",
        "name": "Control de Autoclave",
        "module": "autoclaves",
        "version": 1,
        "fields": [
            {"key": "temperatura", "label": "Temperatura (°C)", "type": "number", "required": True},
            {"key": "presion", "label": "Presion (psi)", "type": "number", "required": True},
            {"key": "tiempo", "label": "Tiempo (min)", "type": "number", "required": True},
            {"key": "ciclo", "label": "Tipo de Ciclo", "type": "select", "required": True, "options": ["Liquidos", "Instrumentos", "Residuos", "Rapido"]},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        ]
    },
    {
        "id": "tpl-ultracongeladores",
        "name": "Registro de Ultracongeladores",
        "module": "ultracongeladores",
        "version": 1,
        "fields": [
            {"key": "temperatura", "label": "Temperatura (°C)", "type": "number", "required": True, "min": -90, "max": -60},
            {"key": "alarma", "label": "Estado de Alarma", "type": "select", "required": True, "options": ["Normal", "Alerta", "Critico"]},
            {"key": "respaldo_co2", "label": "Respaldo CO2", "type": "select", "required": True, "options": ["OK", "Bajo", "Vacio"]},
            {"key": "observaciones", "label": "Observaciones", "type": "text", "required": False},
        ]
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
        ]
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
        ]
    }
]

def seed_templates(db: Session):
    if db.query(models.Template).count() == 0:
        for tpl in TEMPLATES_SEED:
            template = models.Template(
                id=tpl["id"],
                name=tpl["name"],
                version=tpl["version"],
                structure_json=json.dumps(tpl)
            )
            db.add(template)
        db.commit()
        print(f"Plantillas seeded: {len(TEMPLATES_SEED)} templates")

@router.get("/api/templates")
def list_templates(db: Session = Depends(get_db)):
    templates = db.query(models.Template).all()
    result = []
    for t in templates:
        struct = json.loads(t.structure_json)
        result.append({
            "id": t.id,
            "name": struct.get("name", t.name),
            "module": struct.get("module", ""),
            "version": t.version,
            "fields": struct.get("fields", [])
        })
    return result

@router.get("/api/templates/{template_id}")
def get_template(template_id: str, db: Session = Depends(get_db)):
    t = db.query(models.Template).filter(models.Template.id == template_id).first()
    if not t:
        raise HTTPException(status_code=404, detail="Plantilla no encontrada")
    struct = json.loads(t.structure_json)
    return {
        "id": t.id,
        "name": t.name,
        "module": struct.get("module", ""),
        "version": t.version,
        "fields": struct.get("fields", [])
    }

@router.post("/api/form-entries")
def save_form_entry(payload: Dict[str, Any], db: Session = Depends(get_db)):
    entry = models.FormEntry(
        id=payload.get("id", f"fe-{datetime.utcnow().timestamp()}"),
        module=payload.get("module", ""),
        date=payload.get("date", ""),
        user_id=payload.get("user_id", ""),
        device_id=payload.get("device_id", ""),
        version=payload.get("version", 1),
        data_json=json.dumps(payload.get("data", {})),
        status=payload.get("status", "saved")
    )
    db.add(entry)
    db.commit()
    return {"success": True, "id": entry.id}

@router.get("/api/form-entries")
def get_form_entries(module: str = None, date: str = None, db: Session = Depends(get_db)):
    query = db.query(models.FormEntry)
    if module:
        query = query.filter(models.FormEntry.module == module)
    if date:
        query = query.filter(models.FormEntry.date == date)
    entries = query.order_by(models.FormEntry.date.desc()).all()
    result = []
    for e in entries:
        result.append({
            "id": e.id,
            "module": e.module,
            "date": e.date,
            "user_id": e.user_id,
            "device_id": e.device_id,
            "version": e.version,
            "data": json.loads(e.data_json),
            "status": e.status,
            "created_at": e.created_at.isoformat(),
            "updated_at": e.updated_at.isoformat()
        })
    return result
