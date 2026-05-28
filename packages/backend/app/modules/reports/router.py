import json

from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import HTMLResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.dependencies import get_current_user
from app.models.form_entry import FormEntry
from app.models.day_closure import DayClosure
from app.models.month_closure import MonthClosure
from app.services.pdf_generator import PDFGenerator
from app.services.google_drive import GoogleDriveService

router = APIRouter(prefix="/api", tags=["PDFs"])
drive_service = GoogleDriveService()


@router.post("/pdf/generate-bitacora")
async def generate_bitacora_pdf(
    payload: dict,
    current_user: dict = Depends(get_current_user),
):
    data = payload.get("data", {})
    fields = payload.get("fields", {})
    pdf = PDFGenerator.generate_bitacora_html(data, fields)
    return {"success": True, "html": pdf}


@router.get("/pdf/view/{module}/{date}")
async def view_bitacora_pdf(
    module: str,
    date: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(
        select(FormEntry).where(
            FormEntry.module == module,
            FormEntry.date == date,
        )
    )
    entries = result.scalars().all()
    if not entries:
        raise HTTPException(status_code=404, detail="No hay registros para esta fecha y modulo")

    all_html = []
    for entry in entries:
        data = {
            "id": entry.id, "module": entry.module, "date": entry.date,
            "user_id": entry.user_id, "version": entry.version, "status": entry.status,
        }
        fields = json.loads(entry.data_json) if entry.data_json else {}
        html = PDFGenerator.generate_bitacora_html(data, fields)
        all_html.append(html)

    return HTMLResponse(content="<hr>".join(all_html))


@router.get("/pdf/templates")
async def list_templates(
    current_user: dict = Depends(get_current_user),
):
    return {
        "templates": [
            {"id": "default", "name": "Plantilla General"},
            {"id": "incubadoras", "name": "Bitacora de Incubadoras"},
            {"id": "autoclaves", "name": "Control de Autoclave"},
            {"id": "ultracongeladores", "name": "Registro de Ultracongeladores"},
            {"id": "equipos", "name": "Bitacora de Equipos"},
            {"id": "procesamiento", "name": "Control de Procesamiento"},
        ]
    }


@router.get("/drive/status")
async def drive_status(
    current_user: dict = Depends(get_current_user),
):
    return drive_service.get_status()


@router.get("/pdf/cover-preview/{year}/{month}")
async def preview_cover_page(
    year: int,
    month: int,
    current_user: dict = Depends(get_current_user),
    generated_by: str = "Administrador",
    db: AsyncSession = Depends(get_session),
):
    start = f"{year}-{month:02d}-01"
    end = f"{year+1}-01-01" if month == 12 else f"{year}-{month+1:02d}-01"

    result = await db.execute(
        select(FormEntry).where(FormEntry.date >= start, FormEntry.date < end)
    )
    entries = result.scalars().all()

    result = await db.execute(
        select(MonthClosure).where(
            MonthClosure.year == year,
            MonthClosure.month == month,
        )
    )
    month_closure = result.scalar_one_or_none()

    entries_data = [
        {"id": e.id, "module": e.module, "date": e.date, "user_id": e.user_id, "status": e.status}
        for e in entries
    ]
    closure_data = None
    if month_closure:
        closure_data = {
            "status": month_closure.status,
            "closed_by": month_closure.closed_by,
            "closed_at": month_closure.closed_at.isoformat() if month_closure.closed_at else None,
        }

    html = PDFGenerator.generate_cover_page_html(
        year=year, month=month, entries=entries_data,
        closure_data=closure_data, generated_by=generated_by,
    )
    return HTMLResponse(content=html)


@router.post("/export/monthly")
async def export_monthly(
    year: int,
    month: int,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    start = f"{year}-{month:02d}-01"
    end = f"{year+1}-01-01" if month == 12 else f"{year}-{month+1:02d}-01"

    result = await db.execute(
        select(FormEntry).where(FormEntry.date >= start, FormEntry.date < end)
    )
    entries = result.scalars().all()

    result = await db.execute(
        select(DayClosure).where(DayClosure.date >= start, DayClosure.date < end)
    )
    closures = result.scalars().all()

    result = await db.execute(
        select(MonthClosure).where(
            MonthClosure.year == year,
            MonthClosure.month == month,
        )
    )
    month_closure = result.scalar_one_or_none()

    entries_data = [
        {"id": e.id, "module": e.module, "date": e.date, "user_id": e.user_id, "status": e.status}
        for e in entries
    ]
    closure_data = None
    if month_closure:
        closure_data = {"status": month_closure.status, "closed_by": month_closure.closed_by}

    cover_html = PDFGenerator.generate_cover_page_html(year=year, month=month, entries=entries_data, closure_data=closure_data)
    pdfs = [{"folio": f"PORTADA-{year}{month:02d}", "type": "cover", "html_content": cover_html}]

    for entry in entries:
        data = {
            "id": entry.id, "module": entry.module, "date": entry.date,
            "user_id": entry.user_id, "version": entry.version, "status": entry.status,
        }
        fields = json.loads(entry.data_json) if entry.data_json else {}
        folio = f"BL-{entry.date.replace('-', '')}-{entry.id[-4:]}"
        html = PDFGenerator.generate_bitacora_html(data, fields)
        pdfs.append({"folio": folio, "module": entry.module, "date": entry.date, "html_content": html})

    for closure in closures:
        data = {"date": closure.date, "status": closure.status, "closed_by": closure.closed_by, "notes": closure.notes}
        folio = f"CL-{closure.date.replace('-', '')}"
        html = PDFGenerator.generate_closure_html(data)
        pdfs.append({"folio": folio, "type": "closure", "date": closure.date, "html_content": html})

    export = drive_service.create_monthly_export(pdfs, year, month)
    return {
        "success": True,
        "export": export,
        "total_pdfs": len(pdfs),
        "entries": len(entries),
        "closures": len(closures),
        "has_cover": True,
        "folder": drive_service.get_export_folder_path(year, month),
    }
