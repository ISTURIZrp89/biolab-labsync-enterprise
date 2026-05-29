import uuid
from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class DayClosure(Base):
    __tablename__ = "day_closures"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    date: Mapped[str] = mapped_column(String(10), unique=True, index=True)
    status: Mapped[str] = mapped_column(String(30))
    closed_by: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("usuarios.id")
    )
    closed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    notes: Mapped[str | None] = mapped_column(Text)
    reopen_log_json: Mapped[str] = mapped_column(Text, default="[]")
