import uuid
from datetime import datetime, timezone

from sqlalchemy import String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class AuditLog(Base):
    __tablename__ = "audit_logs"

    id: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=lambda: str(uuid.uuid4())
    )
    action: Mapped[str] = mapped_column(String(50), index=True)
    user_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("usuarios.id")
    )
    device_id: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("devices.id")
    )
    timestamp: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    details_json: Mapped[str | None] = mapped_column(Text)
    entity_id: Mapped[str | None] = mapped_column(String(36), index=True)
    changed_fields_json: Mapped[str | None] = mapped_column(Text)
