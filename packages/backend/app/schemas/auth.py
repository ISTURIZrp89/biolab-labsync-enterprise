from pydantic import BaseModel, EmailStr

from app.models.usuario import UserRole


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class UserCreate(BaseModel):
    email: EmailStr
    password: str
    nombre: str
    role: UserRole = UserRole.LABORATORIO


class UserResponse(BaseModel):
    id: str
    email: str
    nombre: str
    role: UserRole
    activo: bool

    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
