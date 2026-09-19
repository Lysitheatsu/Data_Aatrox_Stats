"""Finding toll roads and roadworks on your route.

OSRM doesn't tell us this, so we take the route and ask Overpass what's
tagged along it. Tolls are toll=yes, roadworks are highway=construction.

A route can be 1000 points long which is too many for one query, so we only
check about 25 of them.

This is what OSM has, not live traffic. Tolls don't move so that's fine,
roadworks only show up if someone mapped them.
"""

from __future__ import annotations

from .http import fetch_json

OVERPASS_URL = "https://overpass-api.de/api/interpreter"

# how many points along the route we check
SAMPLE_POINTS = 25

# how far either side to look, in metres
SEARCH_RADIUS = 120


def sample_route(geometry: list[list[float]], count: int = SAMPLE_POINTS) -> list[list[float]]:
    """Cut a long route down to a few evenly spaced points."""
    if not geometry:
        return []
    if len(geometry) <= count:
        return geometry
    step = len(geometry) // count
    return geometry[::step]


def _around_clause(points: list[list[float]]) -> str:
    """Overpass wants lat,lon. Our points are lon,lat."""
    pairs = ",".join(f"{p[1]},{p[0]}" for p in points)
    return f"(around:{SEARCH_RADIUS},{pairs})"


def _names(elements: list[dict]) -> list[str]:
    """Road names, no duplicates, skipping the unnamed ones."""
    seen = []
    for element in elements:
        name = (element.get("tags") or {}).get("name")
        if name and name not in seen:
            seen.append(name)
    return seen


async def road_info(geometry: list[list[float]]) -> dict:
    """Look for tolls and roadworks on this route."""
    points = sample_route(geometry)
    if not points:
        return {"toll_roads": [], "construction": []}

    around = _around_clause(points)
    query = (
        "[out:json][timeout:60];"
        f'(way["toll"="yes"]["highway"]{around};'
        f'way["highway"="construction"]{around};);'
        "out tags;"
    )

    payload = await fetch_json(OVERPASS_URL, method="POST", data={"data": query})
    elements = payload.get("elements", [])

    tolls = [e for e in elements if (e.get("tags") or {}).get("toll") == "yes"]
    works = [
        e for e in elements if (e.get("tags") or {}).get("highway") == "construction"
    ]

    return {"toll_roads": _names(tolls), "construction": _names(works)}
