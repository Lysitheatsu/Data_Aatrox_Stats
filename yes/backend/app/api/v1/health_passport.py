"""
health_passport.py

FastAPI router for User Health Passport management.
"""

from datetime import datetime, timezone
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.database.session import get_db
from app.schemas.health_schema import HealthPassportUpdate, HealthPassportResponse
from app.models.health_passport import HealthPassportModel

router = APIRouter(prefix="/health-passport", tags=["Health Passport"])


@router.put("/{user_id}", response_model=HealthPassportResponse)
async def update_health_passport(user_id: str, payload: HealthPassportUpdate, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(HealthPassportModel).where(HealthPassportModel.user_id == user_id))
    passport = result.scalars().first()

    if not passport:
        passport = HealthPassportModel(user_id=user_id)
        db.add(passport)

    passport.blood_group = payload.blood_group
    passport.age = payload.age
    passport.allergies = payload.allergies
    passport.medications = payload.medications
    passport.chronic_conditions = payload.chronic_conditions
    passport.physician_name = payload.physician_name
    passport.physician_phone = payload.physician_phone
    passport.emergency_notes = payload.emergency_notes
    passport.updated_at = datetime.now(timezone.utc)

    await db.flush()

    return HealthPassportResponse(
        user_id=passport.user_id,
        blood_group=passport.blood_group,
        age=passport.age,
        allergies=passport.allergies,
        medications=passport.medications,
        chronic_conditions=passport.chronic_conditions,
        physician_name=passport.physician_name,
        physician_phone=passport.physician_phone,
        emergency_notes=passport.emergency_notes,
        updated_at=passport.updated_at.isoformat()
    )


@router.get("/{user_id}", response_model=HealthPassportResponse)
async def get_health_passport(user_id: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(select(HealthPassportModel).where(HealthPassportModel.user_id == user_id))
    passport = result.scalars().first()

    if not passport:
        raise HTTPException(status_code=404, detail="Health passport not found.")

    return HealthPassportResponse(
        user_id=passport.user_id,
        blood_group=passport.blood_group,
        age=passport.age,
        allergies=passport.allergies,
        medications=passport.medications,
        chronic_conditions=passport.chronic_conditions,
        physician_name=passport.physician_name,
        physician_phone=passport.physician_phone,
        emergency_notes=passport.emergency_notes,
        updated_at=passport.updated_at.isoformat()
    )