"""
sos_circle.py

FastAPI router for SOS Circle Emergency Contacts management.
"""

from datetime import datetime, timezone
import uuid
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database.session import get_db
from app.schemas.health_schema import EmergencyContactCreate, EmergencyContactResponse
from app.models.contact import EmergencyContactModel

router = APIRouter(prefix="/sos-circle", tags=["SOS Circle Contacts"])


@router.post("/{user_id}/contacts", response_model=EmergencyContactResponse, status_code=status.HTTP_201_CREATED)
async def add_emergency_contact(user_id: str, payload: EmergencyContactCreate, db: AsyncSession = Depends(get_db)):
    contact_id = f"cnt_{uuid.uuid4().hex[:12]}"
    contact = EmergencyContactModel(
        contact_id=contact_id,
        user_id=user_id,
        name=payload.name,
        phone_number=payload.phone_number,
        relationship=payload.relationship,
        is_primary=payload.is_primary,
        notify_sms=payload.notify_sms
    )

    db.add(contact)
    await db.flush()

    return EmergencyContactResponse(
        contact_id=contact.contact_id,
        user_id=contact.user_id,
        name=contact.name,
        phone_number=contact.phone_number,
        relationship=contact.relationship,
        is_primary=contact.is_primary,
        notify_sms=contact.notify_sms,
        created_at=contact.created_at.isoformat()
    )


@router.get("/{user_id}/contacts", response_model=List[EmergencyContactResponse])
async def list_emergency_contacts(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(EmergencyContactModel).where(EmergencyContactModel.user_id == user_id))
    contacts = result.scalars().all()

    return [
        EmergencyContactResponse(
            contact_id=c.contact_id,
            user_id=c.user_id,
            name=c.name,
            phone_number=c.phone_number,
            relationship=c.relationship,
            is_primary=c.is_primary,
            notify_sms=c.notify_sms,
            created_at=c.created_at.isoformat()
        )
        for c in contacts
    ]