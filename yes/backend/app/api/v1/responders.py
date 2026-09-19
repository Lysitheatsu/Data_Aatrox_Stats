"""
responders.py

FastAPI router for emergency responder tracking & dispatch management.
"""

from datetime import datetime, timezone
from typing import List
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database.session import get_db
from app.models.responder import ResponderModel

router = APIRouter(prefix="/responders", tags=["Emergency Responders"])


class ResponderResponse(BaseModel):
    responder_id: str
    name: str
    role: str
    phone_number: str
    latitude: float
    longitude: float
    is_available: bool
    updated_at: str


@router.get("/nearby", response_model=List[ResponderResponse])
async def get_nearby_responders(
    lat: float,
    lng: float,
    radius_km: float = 10.0,
    db: AsyncSession = Depends(get_db)
):
    result = await db.execute(select(ResponderModel).where(ResponderModel.is_available == True))
    responders = result.scalars().all()

    return [
        ResponderResponse(
            responder_id=r.responder_id,
            name=r.name,
            role=r.role,
            phone_number=r.phone_number,
            latitude=r.latitude,
            longitude=r.longitude,
            is_available=r.is_available,
            updated_at=r.updated_at.isoformat()
        )
        for r in responders
    ]
