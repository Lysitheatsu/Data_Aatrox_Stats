"""
health_passport.py

SQLAlchemy ORM model for storing User Health Passport & Medical Records.
"""

from datetime import datetime, timezone
from sqlalchemy import String, Integer, DateTime, JSON, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class HealthPassportModel(Base):
    __tablename__ = "health_passports"

    user_id: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)
    blood_group: Mapped[str] = mapped_column(String(16), default="UNKNOWN")
    age: Mapped[int] = mapped_column(Integer, default=0)

    allergies: Mapped[dict] = mapped_column(JSON, default=list)
    medications: Mapped[dict] = mapped_column(JSON, default=list)
    chronic_conditions: Mapped[dict] = mapped_column(JSON, default=list)

    physician_name: Mapped[str] = mapped_column(String(128), nullable=True)
    physician_phone: Mapped[str] = mapped_column(String(32), nullable=True)
    emergency_notes: Mapped[str] = mapped_column(Text, nullable=True)

    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
