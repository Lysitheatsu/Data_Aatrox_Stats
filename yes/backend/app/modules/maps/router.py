"""Module 1 — Maps Intelligence.

Just the endpoints. The real work is in services/, which talks to
OpenStreetMap: OSRM for routes, Nominatim for search, Overpass for nearby
places and Open-Meteo for weather.
"""

from __future__ import annotations

from enum import Enum

import httpx
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from app.shared.context import GeoLocation

from .services import ev, fuel, geocoding, journey as journey_service, places, road_info, routing

router = APIRouter(prefix="/maps", tags=["Maps Intelligence"])


class TravelMode(str, Enum):
    driving = "driving"
    walking = "walking"
    cycling = "cycling"


class RouteRequest(BaseModel):
    origin: GeoLocation
    destination: GeoLocation
    mode: TravelMode = TravelMode.driving
    # send the route back and we can check for tolls, roadworks and
    # charging stops. [lon, lat] pairs, same as /maps/routes gives you.
    geometry: list[list[float]] = []


class RouteStep(BaseModel):
    """One turn in the directions."""

    instruction: str
    distance_m: int
    road: str | None = None
    # [lon, lat] of where the turn is
    location: list[float] | None = None


class RouteOption(BaseModel):
    summary: str
    distance_km: float
    eta_minutes: int
    has_tolls: bool = False
    # turn by turn directions for this route
    steps: list[RouteStep] = []
    # true when we worked the time out ourselves instead of OSRM giving it
    # to us. happens for walking and cycling, so show it as "about 31 min"
    eta_is_estimated: bool = False
    # [lon, lat] pairs for drawing the line on the map
    geometry: list[list[float]] = []


class RouteResponse(BaseModel):
    mode: TravelMode
    options: list[RouteOption]


def _upstream_error(exc: Exception) -> HTTPException:
    """Turn a failed call into a 502 instead of leaking the raw error."""
    return HTTPException(status_code=502, detail=f"Map service unavailable: {exc}")


@router.get("/search", response_model=list[GeoLocation])
async def search_places(
    q: str = Query(..., min_length=1, description="What to search for"),
    limit: int = Query(5, ge=1, le=20),
    latitude: float | None = Query(None, ge=-90, le=90),
    longitude: float | None = Query(None, ge=-180, le=180),
) -> list[GeoLocation]:
    """Search for a place by name, preferring places near the user."""
    try:
        return await geocoding.search(q, limit=limit, latitude=latitude, longitude=longitude)
    except httpx.HTTPError as exc:
        raise _upstream_error(exc) from exc


@router.post("/routes", response_model=RouteResponse)
async def plan_routes(request: RouteRequest) -> RouteResponse:
    """Plan a route between two points."""
    try:
        options = await routing.plan_routes(
            request.origin, request.destination, request.mode.value
        )
    except routing.RoutingError as exc:
        # not a server problem, it just can't route between those points
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except httpx.HTTPError as exc:
        raise _upstream_error(exc) from exc

    return RouteResponse(
        mode=request.mode,
        options=[RouteOption(**option) for option in options],
    )


class NearbyPlace(BaseModel):
    name: str
    category: str
    distance_km: float
    location: GeoLocation


# Categories supported by Location Intelligence (see SPECIFICATION.md).
NEARBY_CATEGORIES = set(places.CATEGORY_TAGS)


@router.get("/nearby", response_model=list[NearbyPlace])
async def nearby(
    category: str = Query(..., description=f"One of: {', '.join(sorted(NEARBY_CATEGORIES))}"),
    latitude: float = Query(..., ge=-90, le=90),
    longitude: float = Query(..., ge=-180, le=180),
    radius_m: int = Query(2000, ge=100, le=20000),
) -> list[NearbyPlace]:
    """Find places nearby, closest first."""
    try:
        found = await places.nearby(category, latitude, longitude, radius_m)
    except places.UnknownCategory as exc:
        raise HTTPException(
            status_code=400,
            detail=f"Unknown category '{exc}'. Try one of: {', '.join(sorted(NEARBY_CATEGORIES))}",
        ) from exc
    except httpx.HTTPError as exc:
        raise _upstream_error(exc) from exc

    return [NearbyPlace(**place) for place in found]


class FuelEstimate(BaseModel):
    """Roughly what the trip costs. An estimate, so the numbers we used
    come back with it."""

    cost: float
    litres: float | None = None
    consumption_per_100km: float
    price_per_unit: float
    unit: str


class ChargingStop(BaseModel):
    name: str
    distance_km: float


class ChargingPlan(BaseModel):
    stops_needed: int
    assumed_range_km: float
    chargers: list[ChargingStop] = []


class JourneyInfo(BaseModel):
    weather_summary: str
    air_quality_index: int | None = None
    # the public server has no traffic data, so leave this empty rather
    # than making a number up
    traffic_delay_minutes: int | None = None
    estimated_fuel_cost: float | None = None
    # the full breakdown so the app can show how we got the number
    fuel: FuelEstimate | None = None
    ev: FuelEstimate | None = None
    # what's on the road ahead, from OSM
    toll_roads: list[str] = []
    construction: list[str] = []
    charging: ChargingPlan | None = None


@router.post("/journey-info", response_model=JourneyInfo)
async def journey_info(
    request: RouteRequest,
    distance_km: float | None = Query(
        None,
        ge=0,
        description="Route distance, for the fuel estimate. Leave out to skip it.",
    ),
) -> JourneyInfo:
    """Weather, air quality and roughly what the fuel costs."""
    try:
        conditions = await journey_service.journey_conditions(
            request.origin, request.destination
        )
    except httpx.HTTPError as exc:
        raise _upstream_error(exc) from exc

    petrol = ev_estimate = None
    if distance_km:
        petrol = fuel.petrol_cost(distance_km)
        ev_estimate = fuel.ev_cost(distance_km)

    # these need the actual roads, not just the start and end
    tolls: list[str] = []
    works: list[str] = []
    charging = None
    if request.geometry:
        try:
            found = await road_info.road_info(request.geometry)
            tolls = found["toll_roads"]
            works = found["construction"]
            if distance_km:
                charging = await ev.charging_plan(request.geometry, distance_km)
        except httpx.HTTPError:
            # nice to have, don't fail the whole thing over it
            pass

    return JourneyInfo(
        **conditions,
        estimated_fuel_cost=petrol["cost"] if petrol else None,
        fuel=FuelEstimate(**petrol) if petrol else None,
        ev=FuelEstimate(**ev_estimate) if ev_estimate else None,
        toll_roads=tolls,
        construction=works,
        charging=ChargingPlan(**charging) if charging else None,
    )