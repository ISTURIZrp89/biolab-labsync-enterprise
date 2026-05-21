from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from datetime import datetime
import json
from typing import Dict, Any

import models
from database import get_db
from services.pdf_generator import PDFGenerator
from services.google_drive import GoogleDriveService

router = APIRouter(tags=["PDFs"])
drive_service = GoogleDriveService()

@router.post("/api/pdf/generate-bitacora")
def generate_bitacora_pdf(payload: Dict[str, Any]):
    data = payload.get("data", {})
    fields = payload.get("fields", {})
    result = PDFGenerator.generate_bitacora_pdf_data(data)
    html = PDFGenerator.generate_bitacora_html(data, fields)
    return {
        "success": True,
        "pdf": result,
        "html": html,
        "qr_data": result.get("qr_data", "")
    }

@router.get("/api/pdf/view/{module}/{date}")
def view_bitacora_pdf(module: str, date: str, db: Session = Depends(get_db)):
    entries = db.query(models.FormEntry).filter(
        models.FormEntry.module == module,
        models.FormEntry.date == date
    ).all()
    if not entries:
        raise HTTPException(status_code=404, detail="No hay registros para esta fecha y modulo")

    all_html = []
    for entry in entries:
        data = {
            "id": entry.id, "module": entry.module, "date": entry.date,
            "user_id": entry.user_id, "version": entry.version, "status": entry.status
        }
        fields = json.loads(entry.data_json) if entry.data_json else {}
        html = PDFGenerator.generate_bitacora_html(data, fields)
        all_html.append(html)

    return HTMLResponse(content="<hr>".join(all_html))

@router.get("/api/pdf/templates")
def list_templates():
    return {
        "templates": [
            {"id": "default", "name": "Plantilla General"},
            {"id": "incubadoras", "name": "Bitacora de Incubadoras"},
            {"id": "autoclaves", "name": "Control de Autoclave"},
            {"id": "ultracongeladores", "name": "Registro de Ultracongeladores"},
            {"id": "equipos", "name": "Bitacora de Equipos"},
            {"id": "procesamiento", "name": "Control de Procesamiento"}
        ]
    }

@router.get("/api/drive/status")
def drive_status():
    return drive_service.get_status()

@router.post("/api/export/monthly")
def export_monthly(year: int, month: int, db: Session = Depends(get_db)):
    start_date = f"{year}-{month:02d}-01"
    if month == 12:
        end_date = f"{year+1}-01-01"
    else:
        end_date = f"{year}-{month+1:02d}-01"

    entries = db.query(models.FormEntry).filter(
        models.FormEntry.date >= start_date,
        models.FormEntry.date < end_date
    ).all()

    closures = db.query(models.DayClosure).filter(
        models.DayClosure.date >= start_date,
        models.DayClosure.date < end_date
    ).all()

    pdfs = []
    for entry in entries:
        data = {
            "id": entry.id, "module": entry.module, "date": entry.date,
            "user_id": entry.user_id, "version": entry.version, "status": entry.status
        }
        fields = json.loads(entry.data_json) if entry.data_json else {}
        folio = f"BL-{entry.date.replace('-','')}-{entry.id[-4:]}"
        html = PDFGenerator.generate_bitacora_html(data, fields)
        pdfs.append({
            "folio": folio,
            "module": entry.module,
            "date": entry.date,
            "html_content": html
        })

    for closure in closures:
        data = {
            "date": closure.date, "status": closure.status,
            "closed_by": closure.closed_by, "notes": closure.notes
        }
        folio = f"CL-{closure.date.replace('-','')}"
        html = PDFGenerator.generate_closure_html(data)
        pdfs.append({
            "folio": folio,
            "type": "closure",
            "date": closure.date,
            "html_content": html
        })

    export = drive_service.create_monthly_export(pdfs, year, month)
    return {
        "success": True,
        "export": export,
        "total_pdfs": len(pdfs),
        "entries": len(entries),
        "closures": len(closures),
        "folder": drive_service.get_export_folder_path(year, month)
    }
