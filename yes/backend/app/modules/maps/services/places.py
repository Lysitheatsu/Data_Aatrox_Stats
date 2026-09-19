"""Finding places near you with Overpass.

Overpass lets you search OpenStreetMap for things by their tags. The spec
uses names like "hospitals" but OSM calls that amenity=hospital, so
CATEGORY_TAGS translates between the two.

Results are either nodes (one point) or ways (a shape, like a whole hospital
site). Ways only get a centre point if you ask for "out center".
"""

from __future__ import annotations

from math import asin, cos, radians, sin, sqrt

from app.shared.context import GeoLocation

from .http import fetch_json

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# our category names -> the OSM tag for them
CATEGORY_TAGS: dict[str, tuple[str, str]] = {
    "restaurants": ("amenity", "restaurant"),
    "hospitals": ("amenity", "hospital"),
    "pharmacies": ("amenity", "pharmacy"),
    "petrol_stations": ("amenity", "fuel"),
    "parking": ("amenity", "parking"),
    "charging_stations": ("amenity", "charging_station"),
    "hotels": ("tourism", "hotel"),
    "attractions": ("tourism", "attraction"),
}


class UnknownCategory(ValueError):
    """Asked for a category we don't know."""


def distance_km(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Distance between two points in km.

    This is straight line, not driving distance, but it's fine for sorting a
    list of nearby places.
    """
    earth_radius = 6371.0
    dlat = radians(lat2 - lat1)
    dlon = radians(lon2 - lon1)
    a = (
        sin(dlat / 2) ** 2
        + cos(radians(lat1)) * cos(radians(lat2)) * sin(dlon / 2) ** 2
    )
    return round(earth_radius * 2 * asin(sqrt(a)), 2)


def build_query(category: str, latitude: float, longitude: float, radius_m: int) -> str:
    """Write the Overpass query for one category."""
    try:
        key, value = CATEGORY_TAGS[category]
    except KeyError as exc:
        raise UnknownCategory(category) from exc

    around = f"(around:{radius_m},{latitude},{longitude})"
    return (
        "[out:json][timeout:25];"
        f'(node["{key}"="{value}"]{around};'
        f'way["{key}"="{value}"]{around};);'
        "out center 30;"
    )


def _coords(element: dict) -> tuple[float, float] | None:
    """Get lat/lon off a result, node or way."""
    if element.get("type") == "node":
        lat, lon = element.get("lat"), element.get("lon")
    else:
        centre = element.get("center") or {}
        lat, lon = centre.get("lat"), centre.get("lon")
    if lat is None or lon is None:
        return None
    return float(lat), float(lon)


async def nearby(
    category: str,
    latitude: float,
    longitude: float,
    radius_m: int = 2000,
) -> list[dict]:
    """Find places near a point, closest first."""
    query = build_query(category, latitude, longitude, radius_m)

    payload = await fetch_json(
        OVERPASS_URL,
        method="POST",
        data={"data": query},
    )

    places = []
    for element in payload.get("elements", []):
        point = _coords(element)
        if point is None:
            continue
        lat, lon = point

        # loads of OSM entries have no name, no point showing those
        name = (element.get("tags") or {}).get("name")
        if not name:
            continue

        places.append(
            {
                "name": name,
                "category": category,
                "distance_km": distance_km(latitude, longitude, lat, lon),
                "location": GeoLocation(label=name, latitude=lat, longitude=lon),
            }
        )

    places.sort(key=lambda p: p["distance_km"])
    return places