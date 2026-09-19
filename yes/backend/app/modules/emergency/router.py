"""Module 3 — Emergency Intelligence.

Immediate access to emergency services and healthcare. V1 stubs below. Treat
these as safety-critical when implemented for real — validate location, confirm
dispatch, and never silently drop an SOS.
"""

from __future__ import annotations

from enum import Enum

from fastapi import APIRouter
from pydantic import BaseModel

from app.shared.context import GeoLocation, context_store

router = APIRouter(prefix="/emergency", tags=["Emergency Intelligence"])


class ServiceType(str, Enum):
    ambulance = "ambulance"
    police = "police"
    fire = "fire"
    roadside = "roadside"


class SOSRequest(BaseModel):
    user_id: str
    location: GeoLocation
    service: ServiceType | None = None
    note: str | None = None


class SOSResponse(BaseModel):
    incident_id: str
    service: ServiceType | None
    notified_contacts: list[str]
    live_location_shared: bool


@router.post("/sos", response_model=SOSResponse)
async def trigger_sos(request: SOSRequest) -> SOSResponse:
    """Trigger an SOS: alert services and the user's emergency contacts (stub)."""
    context = context_store.get(request.user_id)
    return SOSResponse(
        incident_id="incident_0001",
        service=request.service,
        notified_contacts=[c.name for c in context.emergency_contacts],
        live_location_shared=True,
    )


class HealthFacility(BaseModel):
    name: str
    category: str
    distance_km: float
    location: GeoLocation


@router.get("/health-services", response_model=list[HealthFacility])
async def health_services(
    latitude: float, longitude: float
) -> list[HealthFacility]:
    """Nearby hospitals, clinics, pharmacies and blood banks (stub)."""
    here = GeoLocation(latitude=latitude, longitude=longitude)
    return [
        HealthFacility(
            name="City Care Hospital",
            category="hospital",
            distance_km=1.2,
            location=here,
        ),
        HealthFacility(
            name="Life Pharmacy",
            category="pharmacy",
            distance_km=0.3,
            location=here,
        ),
    ]
