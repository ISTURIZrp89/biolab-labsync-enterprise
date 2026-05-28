import json
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from passlib.context import CryptContext
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.dependencies import get_current_user
from app.models.usuario import Usuario
from app.models.audit_log import AuditLog
from app.schemas.auth import UserCreate, UserResponse

router = APIRouter(prefix="/api/users", tags=["Users"])
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


@router.get("", response_model=list[UserResponse])
async def list_users(
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(Usuario))
    users = result.scalars().all()
    return [
        UserResponse(
            id=u.id,
            nombre=u.nombre,
            cargo=u.cargo,
            cargo_operativo=u.cargo_operativo or u.cargo,
            area=u.area or "",
            supervisor=u.supervisor or "",
            firma=u.firma or u.nombre,
            rol=u.rol.value if hasattr(u.rol, "value") else u.rol,
            activo=u.activo,
        )
        for u in users
    ]


@router.get("/{user_id}")
async def get_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    if current_user.get("rol") not in ["ADMIN", "JEFE"] and current_user.get("sub") != user_id:
        raise HTTPException(status_code=403, detail="Permiso denegado")

    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    return UserResponse(
        id=user.id,
        nombre=user.nombre,
        cargo=user.cargo,
        cargo_operativo=user.cargo_operativo or user.cargo,
        area=user.area or "",
        supervisor=user.supervisor or "",
        firma=user.firma or user.nombre,
        rol=user.rol.value if hasattr(user.rol, "value") else user.rol,
        activo=user.activo,
    )


@router.post("")
async def create_user(
    payload: UserCreate,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(Usuario).where(Usuario.id == payload.id))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Usuario ya existe")

    user = Usuario(
        id=payload.id,
        nombre=payload.nombre,
        cargo=payload.cargo or payload.cargo_operativo or "",
        cargo_operativo=payload.cargo_operativo or payload.cargo or "",
        area=payload.area or "Cultivo Celular",
        supervisor=payload.supervisor or "",
        firma=payload.firma or payload.nombre,
        rol=payload.rol,
        pin_hash=pwd_context.hash(payload.pin) if payload.pin else None,
        pass_hash=pwd_context.hash(payload.password) if payload.password else None,
        activo=True,
    )
    db.add(user)
    await db.commit()

    audit = AuditLog(
        action="CREATE_USER",
        user_id=current_user.get("sub"),
        details_json=json.dumps({"created_user_id": user.id, "rol": user.rol}),
    )
    db.add(audit)
    await db.commit()

    return {"success": True, "user": {"id": user.id, "nombre": user.nombre, "rol": user.rol}}


@router.put("/{user_id}")
async def update_user(
    user_id: str,
    payload: dict,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    user = result.scalar_one_or_none()
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

    await db.commit()

    audit = AuditLog(
        action="UPDATE_USER",
        user_id=current_user.get("sub"),
        details_json=json.dumps({"updated_user_id": user_id}),
    )
    db.add(audit)
    await db.commit()

    return {"success": True, "user_id": user_id}


@router.delete("/{user_id}")
async def delete_user(
    user_id: str,
    current_user: dict = Depends(get_current_user),
    db: AsyncSession = Depends(get_session),
):
    if user_id == current_user.get("sub"):
        raise HTTPException(status_code=400, detail="No puedes eliminar tu propio usuario")

    result = await db.execute(select(Usuario).where(Usuario.id == user_id))
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=404, detail="Usuario no encontrado")

    user.activo = False
    await db.commit()

    audit = AuditLog(
        action="DELETE_USER",
        user_id=current_user.get("sub"),
        details_json=json.dumps({"deleted_user_id": user_id}),
    )
    db.add(audit)
    await db.commit()

    return {"success": True, "user_id": user_id}
