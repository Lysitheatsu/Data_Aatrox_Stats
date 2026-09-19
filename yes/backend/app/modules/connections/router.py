"""Module 2 — Connections Intelligence.

Stay connected with family, friends and teams through live location sharing,
groups and privacy controls. V1 stubs below.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum

from fastapi import APIRouter
from pydantic import BaseModel

from app.shared.context import GeoLocation

router = APIRouter(prefix="/connections", tags=["Connections Intelligence"])


class SharingMode(str, Enum):
    time_based = "time_based"
    permanent = "permanent"
    emergency = "emergency"


class GroupType(str, Enum):
    family = "family"
    business = "business"
    custom = "custom"


class LiveShare(BaseModel):
    user_id: str
    display_name: str
    location: GeoLocation
    last_updated: datetime
    mode: SharingMode


class Group(BaseModel):
    group_id: str
    name: str
    type: GroupType
    member_ids: list[str] = []


@router.get("/live", response_model=list[LiveShare])
async def live_shares() -> list[LiveShare]:
    """Everyone currently sharing their live location with the user (stub)."""
    return [
        LiveShare(
            user_id="u_mom",
            display_name="Mom",
            location=GeoLocation(latitude=0.0, longitude=0.0),
            last_updated=datetime.utcnow(),
            mode=SharingMode.permanent,
        )
    ]


@router.get("/groups", response_model=list[Group])
async def groups() -> list[Group]:
    """List the user's family, business and custom groups (stub)."""
    return [Group(group_id="g_family", name="Family", type=GroupType.family)]


class FriendRequest(BaseModel):
    from_user_id: str
    to_user_id: str


@router.post("/friend-requests", status_code=201)
async def send_friend_request(request: FriendRequest) -> dict[str, str]:
    """Send a friend request (stub)."""
    return {"status": "pending", **request.model_dump()}
