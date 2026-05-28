from datetime import datetime, timezone

from sqlalchemy import String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column

from app.core.database import Base


class MonthClosure(Base):
    __tablename__ = "month_closures"

    id: Mapped[str] = mapped_column(String(36), primary_key=True)
    year: Mapped[int] = mapped_column(Integer, nullable=False)
    month: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(30), nullable=False)
    closed_by: Mapped[str | None] = mapped_column(
        String(36), ForeignKey("usuarios.id")
    )
    closed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
    notes: Mapped[str | None] = mapped_column(Text)
    reopen_log_json: Mapped[str] = mapped_column(Text, default="[]")
