from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from datetime import datetime, timedelta
import json
from jose import jwt

import models, schemas
from database import get_db
from config import SECRET_KEY, ALGORITHM, ACCESS_TOKEN_EXPIRE_MINUTES

router = APIRouter(tags=["Auth"])

@router.post("/api/auth/register-device")
def register_device(payload: schemas.DeviceRegister, db: Session = Depends(get_db)):
    device = db.query(models.Device).filter(models.Device.id == payload.device_id).first()
    if not device:
        device = models.Device(
            id=payload.device_id,
            device_name=payload.device_name,
            os=payload.os,
            is_approved=True,
            approved_at=datetime.utcnow()
        )
        db.add(device)
        db.commit()
        db.refresh(device)
    return {"status": "registered", "device_id": device.id, "is_approved": device.is_approved}

@router.post("/api/auth/login", response_model=schemas.Token)
def login(payload: schemas.UserLogin, db: Session = Depends(get_db)):
    user = db.query(models.Usuario).filter(
        models.Usuario.id == payload.user_id,
        models.Usuario.activo == True
    ).first()
    if not user:
        raise HTTPException(status_code=400, detail="Usuario no encontrado o inactivo")

    from passlib.context import CryptContext
    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

    credentials_ok = False
    if payload.pin and user.pin_hash:
        credentials_ok = pwd_context.verify(payload.pin, user.pin_hash)
    elif payload.password and user.pass_hash:
        credentials_ok = pwd_context.verify(payload.password, user.pass_hash)

    if not credentials_ok:
        audit = models.AuditLog(
            id=f"audit-{datetime.utcnow().timestamp()}",
            action="LOGIN_FAILED",
            user_id=payload.user_id,
            device_id=payload.device_id,
            details_json=json.dumps({"reason": "Credencial incorrecta"})
        )
        db.add(audit)
        db.commit()
        raise HTTPException(status_code=400, detail="Credenciales incorrectas")

    access_token = jwt.encode(
        {
            "sub": user.id,
            "rol": user.rol,
            "nombre": user.nombre,
            "exp": datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
        },
        SECRET_KEY,
        algorithm=ALGORITHM
    )

    audit = models.AuditLog(
        id=f"audit-{datetime.utcnow().timestamp()}",
        action="LOGIN",
        user_id=user.id,
        device_id=payload.device_id,
        details_json=json.dumps({"method": "PIN" if payload.pin else "PASSWORD"})
    )
    db.add(audit)
    db.commit()

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user_id": user.id,
        "nombre": user.nombre,
        "rol": user.rol
    }
