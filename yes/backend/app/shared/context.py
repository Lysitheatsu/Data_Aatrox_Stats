"""Shared user context.

The unified user profile is the backbone of ELLY Maps: every module (Maps,
Connections, Emergency, ELLY AI) reads and enriches the same context so the four
systems can work together seamlessly (see reference/SPECIFICATION.md ->
"Shared User Context").

The boilerplate keeps this in-memory. Swap `InMemoryContextStore` for a real
PostgreSQL/Redis-backed implementation as the platform grows.
"""

from __future__ import annotations

from pydantic import BaseModel, Field


class GeoLocation(BaseModel):
    """A point on the map, optionally labelled."""

    label: str | None = None
    address: str | None = None
    latitude: float
    longitude: float


class EmergencyContact(BaseModel):
    name: str
    phone: str
    relationship: str | None = None


class UserContext(BaseModel):
    """Unified profile shared across all ELLY modules."""

    user_id: str
    display_name: str | None = None

    home_address: GeoLocation | None = None
    office_address: GeoLocation | None = None
    favourite_locations: list[GeoLocation] = Field(default_factory=list)
    frequently_visited: list[GeoLocation] = Field(default_factory=list)

    travel_history: list[GeoLocation] = Field(default_factory=list)
    calendar_events: list[str] = Field(default_factory=list)
    healthcare_preferences: dict[str, str] = Field(default_factory=dict)
    emergency_contacts: list[EmergencyContact] = Field(default_factory=list)
    business_locations: list[GeoLocation] = Field(default_factory=list)
    smart_home_devices: list[str] = Field(default_factory=list)


class InMemoryContextStore:
    """Minimal in-memory store for user context.

    Replace with a database-backed repository in production.
    """

    def __init__(self) -> None:
        self._contexts: dict[str, UserContext] = {}

    def get(self, user_id: str) -> UserContext:
        return self._contexts.setdefault(
            user_id, UserContext(user_id=user_id)
        )

    def save(self, context: UserContext) -> UserContext:
        self._contexts[context.user_id] = context
        return context


# Shared singleton used by the module routers.
context_store = InMemoryContextStore()
