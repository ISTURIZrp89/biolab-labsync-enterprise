from datetime import datetime
from typing import Dict, Any, List, Optional
import os
import calendar as cal_module
from jinja2 import Environment, FileSystemLoader

template_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates")
env = Environment(loader=FileSystemLoader(template_dir))

# Spanish month names
_MONTH_NAMES_ES = [
    "", "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
]

MODULE_LABELS = {
    "bitacora": "Bitácora General",
    "incubadoras": "Incubadoras",
    "autoclaves": "Autoclaves",
    "ultracongeladores": "Ultracongeladores",
    "equipos": "Equipos",
    "procesamiento": "Procesamiento",
    "misid": "MISID",
    "solucion_cobre": "Sol. Iones Cobre",
    "muestras": "Muestras",
}

class PDFGenerator:
    @staticmethod
    def generate_bitacora_html(data: Dict[str, Any], fields_data: Dict[str, Any], template_name: str = "bitacora_pdf.html") -> str:
        folio = f"BL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{hash(str(data)) % 10000:04d}"
        template = env.get_template(template_name)
        fields_list = [{"key": k, "value": v} for k, v in fields_data.items()]
        return template.render(
            folio=folio,
            module_name=MODULE_LABELS.get(data.get("module", ""), data.get("module", "")),
            date=data.get("date", ""),
            user_id=data.get("user_id", ""),
            version=data.get("version", 1),
            status=data.get("status", "saved"),
            fields=fields_list,
            qr_data=folio,
            generated_at=datetime.utcnow().isoformat()
        )

    @staticmethod
    def generate_closure_html(closure_data: Dict[str, Any]) -> str:
        folio = f"CL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{hash(str(closure_data)) % 10000:04d}"
        template = env.get_template("closure_report.html")
        return template.render(
            folio=folio,
            date=closure_data.get("date", ""),
            status=closure_data.get("status", ""),
            closed_by=closure_data.get("closed_by", ""),
            notes=closure_data.get("notes", ""),
            qr_data=folio,
            generated_at=datetime.utcnow().isoformat()
        )

    @staticmethod
    def generate_bitacora_pdf_data(data: Dict[str, Any]) -> Dict[str, Any]:
        folio = f"BL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{hash(str(data)) % 10000:04d}"
        return {
            "folio": folio,
            "version": data.get("version", 1),
            "generated_at": datetime.utcnow().isoformat(),
            "module": data.get("module", ""),
            "date": data.get("date", ""),
            "user_id": data.get("user_id", ""),
            "status": data.get("status", "saved"),
            "fields": data.get("data", {}),
            "qr_data": folio
        }

    @staticmethod
    def generate_cover_page_html(
        year: int,
        month: int,
        entries: List[Dict[str, Any]],
        closure_data: Optional[Dict[str, Any]] = None,
        lab_config: Optional[Dict[str, Any]] = None,
        generated_by: str = "Sistema LabSync",
        device_id: Optional[str] = None,
        system_version: str = "1.0.0.0",
    ) -> str:
        """
        Generates a professional brand-consistent cover page for monthly PDF bundles.
        """
        now = datetime.utcnow()
        folio = f"RPT-{year}{month:02d}-{now.strftime('%H%M%S')}-{hash(str(entries)) % 10000:04d}"

        # Derive stats
        _, days_in_month = cal_module.monthrange(year, month)
        unique_users = len({e.get("user_id") for e in entries if e.get("user_id")})
        included_module_keys = list({e.get("module") for e in entries if e.get("module")})
        included_modules = [MODULE_LABELS.get(k, k.title()) for k in included_module_keys]

        # Count closed days from entries
        closed_days_set = set()
        for e in entries:
            if e.get("status") in ("saved", "synced"):
                closed_days_set.add(e.get("date", ""))
        closed_days = len(closed_days_set)

        # Lab defaults
        cfg = lab_config or {}
        lab_name = cfg.get("lab_name", "BioLab S.A. de C.V.")
        lab_area = cfg.get("lab_area", "Laboratorio de Biología Celular")
        lab_address = cfg.get("lab_address", "")
        jefe_nombre = cfg.get("jefe_nombre", "")
        jefe_cargo = cfg.get("jefe_cargo", "Jefe de Laboratorio")
        director_nombre = cfg.get("director_nombre", "")
        director_cargo = cfg.get("director_cargo", "Director General")

        month_name = _MONTH_NAMES_ES[month]
        date_range = f"01 {month_name} {year} – {days_in_month} {month_name} {year}"

        is_closed = closure_data and closure_data.get("status") == "CERRADO"

        template = env.get_template("cover_page.html")
        return template.render(
            folio=folio,
            lab_name=lab_name,
            lab_area=lab_area,
            lab_address=lab_address,
            month_number=f"{month:02d}",
            month_name=month_name,
            month_label=f"{month_name} {year}",
            year=year,
            date_range=date_range,
            is_closed=is_closed,
            total_entries=len(entries),
            closed_days=closed_days,
            active_users=unique_users,
            total_modules=len(included_module_keys),
            included_modules=included_modules,
            generated_by=generated_by,
            generated_at=now.strftime("%d/%m/%Y %H:%M UTC"),
            closed_by=closure_data.get("closed_by") if closure_data else None,
            device_id=device_id,
            system_version=system_version,
            jefe_nombre=jefe_nombre,
            jefe_cargo=jefe_cargo,
            director_nombre=director_nombre,
            director_cargo=director_cargo,
        )

