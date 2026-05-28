from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.core.database import get_session
from app.core.security import hash_password, verify_password, create_access_token
from app.models.usuario import Usuario
from app.schemas.auth import LoginRequest, TokenResponse, UserCreate

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, session: AsyncSession = Depends(get_session)):
    result = await session.execute(select(Usuario).where(Usuario.email == body.email))
    user = result.scalar_one_or_none()
    if not user or not verify_password(body.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Credenciales inválidas")
    token = create_access_token({"sub": user.email, "role": user.role})
    return TokenResponse(access_token=token, token_type="bearer", user=user)


@router.post("/register", status_code=201)
async def register(body: UserCreate, session: AsyncSession = Depends(get_session)):
    result = await session.execute(select(Usuario).where(Usuario.email == body.email))
    if result.scalar_one_or_none():
        raise HTTPException(status_code=400, detail="Email ya registrado")
    user = Usuario(
        email=body.email,
        password_hash=hash_password(body.password),
        nombre=body.nombre,
        role=body.role,
    )
    session.add(user)
    await session.commit()
    return {"message": "Usuario creado exitosamente"}
