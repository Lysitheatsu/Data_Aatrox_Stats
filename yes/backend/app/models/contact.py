"""
contact.py

SQLAlchemy ORM model for storing SOS Circle emergency contacts.
"""

from datetime import datetime, timezone
from sqlalchemy import String, Integer, Boolean, DateTime
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class EmergencyContactModel(Base):
    __tablename__ = "emergency_contacts"

    contact_id: Mapped[str] = mapped_column(String(64), primary_key=True, index=True)
    user_id: Mapped[str] = mapped_column(String(64), index=True, nullable=False)

    name: Mapped[str] = mapped_column(String(128), nullable=False)
    phone_number: Mapped[str] = mapped_column(String(32), nullable=False)
    relationship: Mapped[str] = mapped_column(String(64), default="Family")
    is_primary: Mapped[bool] = mapped_column(Boolean, default=False)
    notify_sms: Mapped[bool] = mapped_column(Boolean, default=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
