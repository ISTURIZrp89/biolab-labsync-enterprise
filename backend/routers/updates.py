from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
import os
import json

router = APIRouter(tags=["Updates"])

VERSION_FILE = os.path.join(os.path.dirname(os.path.dirname(__file__)), "version.json")
UPDATES_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "updates")


def _load_version_info():
    if os.path.exists(VERSION_FILE):
        with open(VERSION_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {
        "version": "7.1.0",
        "build": 1,
        "release_date": "2026-05-20",
        "mandatory": False,
        "release_notes": "BioLab LABSYNC Enterprise v1.0.0.0",
        "downloads": {}
    }


@router.get("/api/updates/check")
def check_updates(current_version: str = "1.0.0.0", platform: str = None):
    version_info = _load_version_info()
    latest_version = version_info.get("version", "1.0.0.0")

    has_update = latest_version != current_version

    response = {
        "latest_version": latest_version,
        "current_version": current_version,
        "has_update": has_update,
        "mandatory": version_info.get("mandatory", False),
        "release_date": version_info.get("release_date", ""),
        "release_notes": version_info.get("release_notes", ""),
        "build": version_info.get("build", 1),
    }

    if platform and platform.lower() in version_info.get("downloads", {}):
        response["download"] = version_info["downloads"][platform.lower()]

    return response


@router.get("/api/updates/version.json")
def get_version_json():
    return _load_version_info()


@router.get("/api/updates/download/{platform}")
def get_download_url(platform: str):
    version_info = _load_version_info()
    downloads = version_info.get("downloads", {})

    if platform.lower() not in downloads:
        raise HTTPException(
            status_code=404,
            detail=f"Descarga no disponible para plataforma: {platform}"
        )

    return downloads[platform.lower()]


@router.get("/api/updates/file/{filename}")
def serve_update_file(filename: str):
    file_path = os.path.join(UPDATES_DIR, filename)

    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Archivo no encontrado")

    return FileResponse(
        file_path,
        filename=filename,
        media_type="application/octet-stream"
    )


@router.get("/api/updates/changelog")
def get_changelog():
    return {
        "versions": [
            {
                "version": "7.1.0",
                "date": "2026-05-20",
                "changes": [
                    "Soporte multiplataforma (Windows, macOS, Linux, iOS, Android)",
                    "Offline-first completo",
                    "JWT authentication",
                    "Dashboard con estadisticas en tiempo real",
                    "Calendario operativo offline",
                    "Auditoria local",
                    "Gestion de usuarios (CRUD)",
                    "Templates PDF para bitacoras",
                    "Auto-update system",
                    "Settings screen",
                ]
            },
            {
                "version": "7.0.0",
                "date": "2026-01-15",
                "changes": [
                    "Version inicial LABSYNC Enterprise",
                    "Login con PIN",
                    "CRUD formularios",
                    "Sincronizacion basica",
                    "Calendario operativo",
                ]
            }
        ]
    }
