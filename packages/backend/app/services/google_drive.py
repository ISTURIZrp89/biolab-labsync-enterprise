class GoogleDriveService:
    def __init__(self):
        self._enabled = False

    def get_status(self) -> dict:
        return {"enabled": self._enabled, "connected": False}

    def create_monthly_export(self, pdfs: list, year: int, month: int) -> dict:
        return {"type": "local", "path": self.get_export_folder_path(year, month), "count": len(pdfs)}

    def get_export_folder_path(self, year: int, month: int) -> str:
        return f"exports/{year}/{month:02d}"
