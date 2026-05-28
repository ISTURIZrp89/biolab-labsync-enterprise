from pydantic import BaseModel, Field
from typing import Optional


class DeviceRegister(BaseModel):
    device_id: str
    device_name: str
    os: str


class LoginRequest(BaseModel):
    user_id: str
    pin: Optional[str] = None
    password: Optional[str] = None
    device_id: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    nombre: str
    rol: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    nombre: str
    rol: str


class UserCreate(BaseModel):
    id: str
    nombre: str
    cargo: Optional[str] = None
    cargo_operativo: Optional[str] = None
    area: Optional[str] = None
    supervisor: Optional[str] = None
    firma: Optional[str] = None
    rol: str
    pin: Optional[str] = None
    password: Optional[str] = None


class UserResponse(BaseModel):
    id: str
    nombre: str
    cargo: Optional[str] = None
    cargo_operativo: Optional[str] = None
    area: str = ""
    supervisor: str = ""
    firma: str = ""
    rol: str
    activo: bool

    class Config:
        from_attributes = True
