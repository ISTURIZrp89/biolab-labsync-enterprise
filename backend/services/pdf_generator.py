from datetime import datetime
from typing import Dict, Any, List, Optional
import os
from jinja2 import Environment, FileSystemLoader

template_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates")
env = Environment(loader=FileSystemLoader(template_dir))

class PDFGenerator:
    @staticmethod
    def generate_bitacora_html(data: Dict[str, Any], fields_data: Dict[str, Any], template_name: str = "bitacora_pdf.html") -> str:
        folio = f"BL-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{hash(str(data)) % 10000:04d}"
        module_names = {
            "incubadoras": "Incubadoras", "autoclaves": "Autoclave",
            "ultracongeladores": "Ultracongeladores", "equipos": "Equipos",
            "procesamiento": "Procesamiento"
        }
        template = env.get_template(template_name)
        fields_list = [{"key": k, "value": v} for k, v in fields_data.items()]
        return template.render(
            folio=folio,
            module_name=module_names.get(data.get("module", ""), data.get("module", "")),
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
