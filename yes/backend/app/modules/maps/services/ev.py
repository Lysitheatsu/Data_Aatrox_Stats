"""Working out if an EV needs to charge on the way.

If the trip is longer than the car can do on one charge you need to stop.
We then look for chargers near where you'd run low, reusing the nearby
places search.

We're guessing the range until the user tells us their car, so that gets
sent back with the answer.
"""

from __future__ import annotations

from . import places

# a normal-ish EV range in km
DEFAULT_RANGE_KM = 350.0

# leave this much in the battery, don't run it flat
RESERVE_FRACTION = 0.15


def usable_range(range_km: float = DEFAULT_RANGE_KM) -> float:
    """The range you'd actually use."""
    return range_km * (1 - RESERVE_FRACTION)


def stops_needed(distance_km: float, range_km: float = DEFAULT_RANGE_KM) -> int:
    """How many times you'd need to stop."""
    usable = usable_range(range_km)
    if distance_km <= usable:
        return 0
    # you start full, so it's one less than you'd think
    return max(1, int((distance_km - 1) // usable))


def stop_points(
    geometry: list[list[float]],
    distance_km: float,
    range_km: float = DEFAULT_RANGE_KM,
) -> list[list[float]]:
    """Roughly where you'd run low.

    Assumes the route points are evenly spaced. Not exactly true but close
    enough to pick a spot to search around.
    """
    count = stops_needed(distance_km, range_km)
    if count == 0 or not geometry:
        return []

    usable = usable_range(range_km)
    points = []
    for stop in range(1, count + 1):
        fraction = min(0.95, (usable * stop) / distance_km)
        index = int(len(geometry) * fraction)
        points.append(geometry[min(index, len(geometry) - 1)])
    return points


async def charging_plan(
    geometry: list[list[float]],
    distance_km: float,
    range_km: float = DEFAULT_RANGE_KM,
) -> dict:
    """Do you need to charge, and where."""
    count = stops_needed(distance_km, range_km)
    result = {
        "stops_needed": count,
        "assumed_range_km": range_km,
        "chargers": [],
    }
    if count == 0:
        return result

    # find chargers near each stop
    for point in stop_points(geometry, distance_km, range_km):
        found = await places.nearby(
            "charging_stations", point[1], point[0], radius_m=15000
        )
        result["chargers"].extend(
            {"name": p["name"], "distance_km": p["distance_km"]} for p in found[:3]
        )
    return result
