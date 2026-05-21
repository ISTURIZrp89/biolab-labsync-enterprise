from datetime import datetime
from typing import List, Dict, Any, Optional
import json
import os
import zipfile
import io

class GoogleDriveService:
    def __init__(self):
        self.enabled = False
        self.root_folder = "LABSYNC"
        self._check_credentials()

    def _check_credentials(self):
        credentials_path = os.getenv("GOOGLE_DRIVE_CREDENTIALS", "")
        self.enabled = bool(credentials_path and os.path.exists(credentials_path))

    def get_status(self) -> dict:
        return {
            "enabled": self.enabled,
            "root_folder": self.root_folder,
            "message": "Google Drive configurado" if self.enabled else "Google Drive no configurado"
        }

    def create_monthly_export(self, pdfs: List[Dict[str, Any]], year: int, month: int) -> Dict[str, Any]:
        export_id = f"EXP-{year}{month:02d}-{datetime.utcnow().strftime('%H%M%S')}"
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zf:
            for pdf in pdfs:
                filename = f"{pdf.get('folio', 'reporte')}.html"
                content = pdf.get("html_content", "<html></html>")
                zf.writestr(f"{year}/{month:02d}/{filename}", content)
        zip_data = zip_buffer.getvalue()
        return {
            "export_id": export_id,
            "year": year,
            "month": month,
            "pdf_count": len(pdfs),
            "size_bytes": len(zip_data),
            "ready_for_upload": self.enabled,
            "message": f"Exportacion mensual {year}-{month:02d} preparada ({len(pdfs)} PDFs)"
        }

    def get_export_folder_path(self, year: int, month: int) -> str:
        return f"{self.root_folder}/{year}/{month:02d}"
