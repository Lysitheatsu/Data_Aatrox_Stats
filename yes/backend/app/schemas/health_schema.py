"""
health_schema.py

Pydantic schemas for Health Passport & Emergency Contacts.
"""

from typing import List, Optional
from pydantic import BaseModel


class HealthPassportUpdate(BaseModel):
    blood_group: str = "UNKNOWN"
    age: int = 0
    allergies: List[str] = []
    medications: List[str] = []
    chronic_conditions: List[str] = []
    physician_name: Optional[str] = None
    physician_phone: Optional[str] = None
    emergency_notes: Optional[str] = None


class HealthPassportResponse(HealthPassportUpdate):
    user_id: str
    updated_at: str


class EmergencyContactCreate(BaseModel):
    name: str
    phone_number: str
    relationship: str = "Family"
    is_primary: bool = False
    notify_sms: bool = True


class EmergencyContactResponse(EmergencyContactCreate):
    contact_id: str
    user_id: str
    created_at: str
