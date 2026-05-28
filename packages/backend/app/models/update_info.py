from datetime import datetime, timezone

from sqlalchemy import String, Boolean, Text, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class UpdateInfo(Base):
    __tablename__ = "updates"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    version: Mapped[str] = mapped_column(String(20), unique=True)
    file_url: Mapped[str | None] = mapped_column(String(500))
    release_notes: Mapped[str | None] = mapped_column(Text)
    is_mandatory: Mapped[bool] = mapped_column(Boolean, default=False)
    released_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
