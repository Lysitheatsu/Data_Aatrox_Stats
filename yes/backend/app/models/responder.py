"""
responder.py

SQLAlchemy ORM model for storing emergency responders & dispatch locations.
"""

from datetime import datetime, timezone
from sqlalchemy import String, Float, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class ResponderModel(Base):
    __tablename__ = "responders"

    responder_id: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String(128), nullable=False)
    role: Mapped[str] = mapped_column(String(64), default="PARAMEDIC") # PARAMEDIC, POLICE, FIRE
    phone_number: Mapped[str] = mapped_column(String(32), nullable=False)

    latitude: Mapped[float] = mapped_column(Float, default=0.0)
    longitude: Mapped[float] = mapped_column(Float, default=0.0)
    is_available: Mapped[bool] = mapped_column(Boolean, default=True)

    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
