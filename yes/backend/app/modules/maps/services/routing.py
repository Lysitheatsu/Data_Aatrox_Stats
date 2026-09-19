"""Working out routes using OSRM.

OSRM is a free routing engine built on OpenStreetMap data.

We use the FOSSGIS servers rather than router.project-osrm.org, because the
project-osrm demo only has the car profile loaded. It accepts /foot/ and /bike/
but quietly gives you car timings back, so walking a couple of km came out as
5 minutes. FOSSGIS runs a separate server per profile, so walking and cycling
give real walking and cycling routes.

Watch out: OSRM wants coordinates as lon,lat (backwards from everywhere else)
and gives distance in metres and time in seconds.
"""

from __future__ import annotations

from app.shared.context import GeoLocation

from .http import fetch_json

BASE_URL = "https://routing.openstreetmap.de"

# our TravelMode values -> which FOSSGIS server to ask
PROFILES = {
    "driving": "routed-car",
    "walking": "routed-foot",
    "cycling": "routed-bike",
}


class RoutingError(RuntimeError):
    """OSRM replied but couldn't find a route."""


# OSRM says what kind of turn it is, we turn that into a sentence.
MANEUVER_WORDS = {
    "turn": "Turn {modifier}",
    "new name": "Continue {modifier}",
    # "Head left" sounds odd before you've moved, so just say "Start"
    "depart": "Start",
    "arrive": "Arrive at your destination",
    "merge": "Merge {modifier}",
    "on ramp": "Take the ramp {modifier}",
    "off ramp": "Take the exit {modifier}",
    "fork": "Keep {modifier}",
    "end of road": "Turn {modifier}",
    "continue": "Continue {modifier}",
    "roundabout": "Enter the roundabout",
    "rotary": "Enter the roundabout",
    "exit roundabout": "Exit the roundabout",
    "exit rotary": "Exit the roundabout",
}


def describe_step(step: dict) -> str:
    """Make one step readable, e.g. "Turn right onto Queen Street"."""
    maneuver = step.get("maneuver") or {}
    kind = maneuver.get("type", "")
    modifier = (maneuver.get("modifier") or "").replace("slight ", "slightly ")
    road = step.get("name") or ""

    # OSRM calls this "continue uturn", nobody says that
    if modifier == "uturn":
        text = "Make a U-turn"
    else:
        template = MANEUVER_WORDS.get(kind, "Continue {modifier}")
        text = template.format(modifier=modifier)

    # tidy up any double spaces
    text = " ".join(text.split())

    if road and kind != "arrive":
        joiner = "onto" if kind in ("turn", "new name", "end of road", "fork") else "on"
        text = f"{text} {joiner} {road}"

    return text


def build_steps(route: dict) -> list[dict]:
    """Get the list of turns out of an OSRM route."""
    steps = []
    for leg in route.get("legs") or []:
        for step in leg.get("steps") or []:
            maneuver = step.get("maneuver") or {}
            steps.append(
                {
                    "instruction": describe_step(step),
                    "distance_m": round(step.get("distance", 0)),
                    "road": step.get("name") or None,
                    # where the turn happens, so the map can follow along
                    "location": maneuver.get("location"),
                }
            )
    return steps


async def plan_routes(
    origin: GeoLocation,
    destination: GeoLocation,
    mode: str = "driving",
) -> list[dict]:
    """Ask OSRM for a route and hand back the options."""
    profile = PROFILES.get(mode, "driving")

    # lon then lat, not a typo
    coords = (
        f"{origin.longitude},{origin.latitude};"
        f"{destination.longitude},{destination.latitude}"
    )

    # the "driving" in the path is just OSRM's url format, the profile is
    # decided by which server we're talking to
    payload = await fetch_json(
        f"{BASE_URL}/{profile}/route/v1/driving/{coords}",
        params={
            "alternatives": "true",
            "overview": "full",
            "geometries": "geojson",
            # gives us the turn by turn directions
            "steps": "true",
        },
    )

    if payload.get("code") != "Ok":
        raise RoutingError(payload.get("message") or payload.get("code", "unknown error"))

    routes = payload.get("routes") or []
    if not routes:
        raise RoutingError("no route found between those points")

    # put the quickest first so "Fastest route" really is the fastest
    routes.sort(key=lambda r: r.get("duration", 0))

    options = []
    for index, route in enumerate(routes):
        options.append(
            {
                "summary": "Fastest route" if index == 0 else f"Alternative {index}",
                "distance_km": round(route["distance"] / 1000, 2),
                "eta_minutes": max(1, round(route["duration"] / 60)),
                # the times are real now, we're not guessing them any more
                "eta_is_estimated": False,
                # these are [lon, lat] pairs
                "geometry": route.get("geometry", {}).get("coordinates", []),
                "steps": build_steps(route),
            }
        )
    return options
