"""
packet_schema.py

Pydantic v2 schemas for Smart Emergency Data Packets.
Matches contract required by Mobile AI System A.
"""

from datetime import datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field


class PacketStatus(str, Enum):
    CREATED = "CREATED"
    QUEUED = "QUEUED"
    UPLOADING = "UPLOADING"
    UPLOADED = "UPLOADED"
    FAILED = "FAILED"
    EXPIRED = "EXPIRED"


class PacketPriority(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class ModelMetadata(BaseModel):
    name: str
    version: str
    checksum: Optional[str] = None
    verified: bool = True


class AiModelsMeta(BaseModel):
    vad: Optional[ModelMetadata] = None
    stt: Optional[ModelMetadata] = None
    speaker: Optional[ModelMetadata] = None
    intent: Optional[ModelMetadata] = None


class LocationData(BaseModel):
    latitude: float
    longitude: float
    accuracy: float = 0.0
    address: Optional[str] = None


class TranscriptData(BaseModel):
    text: str
    confidence: float
    language: str = "en"
    is_partial: bool = False
    speech_probability: float = 0.0
    parsed_intent: Optional[str] = None
    matched_keywords: List[str] = Field(default_factory=list)


class SpeakerData(BaseModel):
    verified: bool
    confidence: float
    profile_id: Optional[str] = None


class BiomarkerSummary(BaseModel):
    stress_level: str = "NORMAL"
    breathing_state: str = "NORMAL"
    confidence: float = 1.0


class MedicalData(BaseModel):
    blood_group: str = "UNKNOWN"
    allergies: List[str] = Field(default_factory=list)
    chronic_conditions: List[str] = Field(default_factory=list)


class DeviceData(BaseModel):
    battery_level: int = 100
    is_charging: bool = False
    cpu_usage_percent: float = 0.0
    ram_free_mb: int = 1024
    network_type: str = "4G"


class EmergencyDataPacketCreate(BaseModel):
    packet_id: str
    session_id: str
    user_id: str
    generated_at: datetime
    packet_version: str = "2.0"
    sequence_number: int = 1
    status: PacketStatus = PacketStatus.QUEUED
    priority: PacketPriority = PacketPriority.CRITICAL
    packet_hash: str
    packet_checksum: str
    ai_models: Optional[AiModelsMeta] = None
    transcript: Optional[TranscriptData] = None
    speaker_verification: Optional[SpeakerData] = None
    biomarker_summary: Optional[BiomarkerSummary] = None
    location: LocationData
    medical: Optional[MedicalData] = None
    device: Optional[DeviceData] = None


class EmergencyDataPacketResponse(BaseModel):
    packet_id: str
    session_id: str
    user_id: str
    status: PacketStatus
    acknowledged_at: datetime
    confirmation_code: str
