import uuid
from datetime import datetime, timezone

from sqlalchemy import String, Boolean, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column
import enum

from app.core.database import Base


class UserRole(str, enum.Enum):
    ADMIN = "ADMIN"
    JEFE = "JEFE"
    LABORATORIO = "LABORATORIO"
    AUDITOR = "AUDITOR"
    DUENO = "DUEÑO"


class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    nombre: Mapped[str] = mapped_column(String(255), nullable=False)
    cargo: Mapped[str | None] = mapped_column(String(255))
    cargo_operativo: Mapped[str | None] = mapped_column(String(255))
    area: Mapped[str] = mapped_column(String(255), default="Cultivo Celular")
    supervisor: Mapped[str] = mapped_column(String(255), default="")
    firma: Mapped[str] = mapped_column(String(255), default="")
    rol: Mapped[UserRole] = mapped_column(
        SAEnum(UserRole, name="user_role"), nullable=False
    )
    pin_hash: Mapped[str | None] = mapped_column(String(255))
    pass_hash: Mapped[str | None] = mapped_column(String(255))
    activo: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
