from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime
from passlib.context import CryptContext
from typing import List, Optional

import models, schemas
from database import get_db
from auth.middleware import get_current_user, require_role

router = APIRouter(tags=["Users"])
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class UserCreateRequest(schemas.UserCreate):
    pin: Optional[str] = None
    password: Optional[str] = None


class UserUpdateRequest:
    nombre: Optional[str] = None
    cargo: Optional[str] = None
    cargo_operativo: Optional[str] = None
    area: Optional[str] = None
    supervisor: Optional[str] = None
    firma: Optional[str] = None
    rol: Optional[str] = None
    pin: Optional[str] = None
    password: Optional[str] = None
    activo: Optional[bool] = None


@router.get("/api/users", response_model=List[dict])
def list_users(
    current_user: models.Usuario = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    users = db.query(models.Usuario).all()
    return [
        {
            "id": u.id,
            "nombre": u.nombre,
            "cargo": u.cargo,
            "cargo_operativo": u.cargo_operativo or u.cargo,
            "area": u.area or "",
            "supervisor": u.supervisor or "",
            "firma": u.firma or u.nombre,
            "rol": u.rol,
            "activo": u.activo,
            "created_at": u.created_at.isoformat() if u.created_at else None,
        }
        for u in users
    ]


@router.get("/api/users/{user_id}")
def get_user(
    user_id: str,
    current_user: models.Usuario = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if current_user.rol not in ["ADMIN", "JEFE"] and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Permiso denegado")

    user = db.query(models.Usuario).filter(models.Usuario.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    return {
        "id": user.id,
        "nombre": user.nombre,
        "cargo": user.cargo,
        "cargo_operativo": user.cargo_operativo or user.cargo,
        "area": user.area or "",
        "supervisor": user.supervisor or "",
        "firma": user.firma or user.nombre,
        "rol": user.rol,
        "activo": user.activo,
        "created_at": user.created_at.isoformat() if user.created_at else None,
    }


@router.post("/api/users")
def create_user(
    payload: UserCreateRequest,
    current_user: models.Usuario = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    existing = db.query(models.Usuario).filter(models.Usuario.id == payload.id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Usuario ya existe")

    user = models.Usuario(
        id=payload.id,
        nombre=payload.nombre,
        cargo=payload.cargo or (payload.cargo_operativo or ""),
        cargo_operativo=payload.cargo_operativo or payload.cargo or "",
        area=getattr(payload, "area", "Cultivo Celular") or "Cultivo Celular",
        supervisor=getattr(payload, "supervisor", "") or "",
        firma=getattr(payload, "firma", "") or payload.nombre,
        rol=payload.rol,
        pin_hash=pwd_context.hash(payload.pin) if payload.pin else None,
        pass_hash=pwd_context.hash(payload.password) if payload.password else None,
        activo=True,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    audit = models.AuditLog(
        id=f"audit-{datetime.utcnow().timestamp()}",
        action="CREATE_USER",
        user_id=current_user.id,
        details_json=f'{{"created_user_id": "{user.id}", "rol": "{user.rol}"}}',
    )
    db.add(audit)
    db.commit()

    return {
        "success": True,
        "user": {
            "id": user.id,
            "nombre": user.nombre,
            "rol": user.rol,
        }
    }


@router.put("/api/users/{user_id}")
def update_user(
    user_id: str,
    payload: dict,
    current_user: models.Usuario = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    user = db.query(models.Usuario).filter(models.Usuario.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    if "nombre" in payload:
        user.nombre = payload["nombre"]
    if "cargo" in payload:
        user.cargo = payload["cargo"]
    if "cargo_operativo" in payload:
        user.cargo_operativo = payload["cargo_operativo"]
    if "area" in payload:
        user.area = payload["area"]
    if "supervisor" in payload:
        user.supervisor = payload["supervisor"]
    if "firma" in payload:
        user.firma = payload["firma"]
    if "rol" in payload:
        user.rol = payload["rol"]
    if "activo" in payload:
        user.activo = payload["activo"]
    if "pin" in payload and payload["pin"]:
        user.pin_hash = pwd_context.hash(payload["pin"])
    if "password" in payload and payload["password"]:
        user.pass_hash = pwd_context.hash(payload["password"])

    db.commit()
    db.refresh(user)

    audit = models.AuditLog(
        id=f"audit-{datetime.utcnow().timestamp()}",
        action="UPDATE_USER",
        user_id=current_user.id,
        details_json=f'{{"updated_user_id": "{user_id}"}}',
    )
    db.add(audit)
    db.commit()

    return {"success": True, "user_id": user_id}


@router.delete("/api/users/{user_id}")
def delete_user(
    user_id: str,
    current_user: models.Usuario = Depends(require_role("ADMIN")),
    db: Session = Depends(get_db)
):
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="No puedes eliminar tu propio usuario")

    user = db.query(models.Usuario).filter(models.Usuario.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    user.activo = False
    db.commit()

    audit = models.AuditLog(
        id=f"audit-{datetime.utcnow().timestamp()}",
        action="DELETE_USER",
        user_id=current_user.id,
        details_json=f'{{"deleted_user_id": "{user_id}"}}',
    )
    db.add(audit)
    db.commit()

    return {"success": True, "user_id": user_id}
