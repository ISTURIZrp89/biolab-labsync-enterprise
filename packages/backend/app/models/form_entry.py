import uuid
from datetime import datetime, timezone

from sqlalchemy import String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class FormEntry(Base):
    __tablename__ = "form_entries"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    module: Mapped[str] = mapped_column(String(100), index=True)
    date: Mapped[str] = mapped_column(String(10), index=True)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("usuarios.id")
    )
    device_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("devices.id")
    )
    version: Mapped[int] = mapped_column(Integer, default=1)
    data_json: Mapped[str] = mapped_column(Text)
    checksum: Mapped[str | None] = mapped_column(String(64))
    status: Mapped[str] = mapped_column(String(20))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
        onupdate=lambda: datetime.now(timezone.utc),
    )
