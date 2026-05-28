from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException
from passlib.context import CryptContext
from jose import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
import json

from app.core.database import get_session
from app.core.config import settings
from app.models.usuario import Usuario
from app.models.device import Device
from app.models.audit_log import AuditLog
from app.schemas.auth import DeviceRegister, LoginRequest, LoginResponse

router = APIRouter(prefix="/api/auth", tags=["Auth"])
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


@router.post("/register-device")
async def register_device(payload: DeviceRegister, db: AsyncSession = Depends(get_session)):
    result = await db.execute(select(Device).where(Device.id == payload.device_id))
    device = result.scalar_one_or_none()
    if not device:
        device = Device(
            id=payload.device_id,
            device_name=payload.device_name,
            os=payload.os,
            is_approved=True,
            approved_at=datetime.now(timezone.utc),
        )
        db.add(device)
        await db.commit()
        await db.refresh(device)
    return {"status": "registered", "device_id": device.id, "is_approved": device.is_approved}


@router.post("/login", response_model=LoginResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_session)):
    result = await db.execute(
        select(Usuario).where(
            Usuario.id == payload.user_id,
            Usuario.activo == True,
        )
    )
    user = result.scalar_one_or_none()
    if not user:
        raise HTTPException(status_code=400, detail="Usuario no encontrado o inactivo")

    credentials_ok = False
    if payload.pin and user.pin_hash:
        credentials_ok = pwd_context.verify(payload.pin, user.pin_hash)
    elif payload.password and user.pass_hash:
        credentials_ok = pwd_context.verify(payload.password, user.pass_hash)

    if not credentials_ok:
        audit = AuditLog(
            action="LOGIN_FAILED",
            user_id=payload.user_id,
            device_id=payload.device_id,
            details_json=json.dumps({"reason": "Credencial incorrecta"}),
        )
        db.add(audit)
        await db.commit()
        raise HTTPException(status_code=400, detail="Credenciales incorrectas")

    access_token = jwt.encode(
        {
            "sub": user.id,
            "rol": user.rol.value if hasattr(user.rol, "value") else user.rol,
            "nombre": user.nombre,
            "exp": datetime.now(timezone.utc).timestamp() + settings.access_token_expire_minutes * 60,
        },
        settings.secret_key,
        algorithm=settings.algorithm,
    )

    audit = AuditLog(
        action="LOGIN",
        user_id=user.id,
        device_id=payload.device_id,
        details_json=json.dumps({"method": "PIN" if payload.pin else "PASSWORD"}),
    )
    db.add(audit)
    await db.commit()

    return LoginResponse(
        access_token=access_token,
        user_id=user.id,
        nombre=user.nombre,
        rol=user.rol.value if hasattr(user.rol, "value") else user.rol,
    )
