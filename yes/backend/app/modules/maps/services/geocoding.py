"""Turning a place name into coordinates and back again.

Uses Nominatim, which is OpenStreetMap's search. Free and no API key needed.
It sends lat/lon back as text so we convert them to numbers here.
"""

from __future__ import annotations

from app.shared.context import GeoLocation

from .http import fetch_json

SEARCH_URL = "https://nominatim.openstreetmap.org/search"
REVERSE_URL = "https://nominatim.openstreetmap.org/reverse"


def _to_location(result: dict) -> GeoLocation:
    """Make a GeoLocation from one search result."""
    # name is nicer to show but not every result has one
    label = result.get("name") or result.get("display_name")
    address = result.get("display_name")

    return GeoLocation(
        label=label,
        address=address,
        latitude=float(result["lat"]),
        longitude=float(result["lon"]),
    )


async def search(query: str, limit: int = 5, latitude: float | None = None, longitude: float | None = None,
) -> list[GeoLocation]:
    """Search for places by name, preferring places near the user."""
    params = {"q": query, "format": "jsonv2", "limit": limit,}
    if latitude is not None and longitude is not None:
        distance = 0.5
        params["viewbox"] = (f"{longitude - distance}," f"{latitude + distance}," f"{longitude + distance}," f"{latitude - distance}")
    results = await fetch_json(
        SEARCH_URL,
        params=params,
    )
    return [_to_location(r) for r in results]


async def reverse(latitude: float, longitude: float) -> GeoLocation | None:
    """Find what's at these coordinates."""
    result = await fetch_json(
        REVERSE_URL,
        params={"lat": latitude, "lon": longitude, "format": "jsonv2"},
    )
    # when it finds nothing it sends an error in the body, not a 404
    if not result or "error" in result:
        return None
    return _to_location(result)