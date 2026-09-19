"""
emergency_packet.py

SQLAlchemy ORM model for storing validated Emergency Data Packets.
"""

from datetime import datetime, timezone
from sqlalchemy import String, Integer, Float, DateTime, Text, JSON
from sqlalchemy.orm import Mapped, mapped_column

from app.database.session import Base


class EmergencyPacketModel(Base):
    __tablename__ = "emergency_packets"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True, autoincrement=True)
    packet_id: Mapped[str] = mapped_column(String(64), unique=True, index=True, nullable=False)
    session_id: Mapped[str] = mapped_column(String(64), index=True, nullable=False)
    user_id: Mapped[str] = mapped_column(String(64), index=True, nullable=False)

    packet_version: Mapped[str] = mapped_column(String(16), default="2.0")
    sequence_number: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(32), default="QUEUED")
    priority: Mapped[str] = mapped_column(String(32), default="CRITICAL")

    packet_hash: Mapped[str] = mapped_column(String(128), nullable=False)
    packet_checksum: Mapped[str] = mapped_column(String(64), nullable=False)

    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    address: Mapped[str] = mapped_column(String(256), nullable=True)

    transcript_text: Mapped[str] = mapped_column(Text, nullable=True)
    parsed_intent: Mapped[str] = mapped_column(String(64), nullable=True)
    speech_confidence: Mapped[float] = mapped_column(Float, default=0.0)

    ai_models_meta: Mapped[dict] = mapped_column(JSON, nullable=True)
    biomarker_summary: Mapped[dict] = mapped_column(JSON, nullable=True)
    medical_data: Mapped[dict] = mapped_column(JSON, nullable=True)
    device_data: Mapped[dict] = mapped_column(JSON, nullable=True)

    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    acknowledged_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
