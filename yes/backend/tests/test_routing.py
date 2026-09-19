"""Tests for the OSRM routing service."""

from __future__ import annotations

import httpx
import pytest
import respx

from app.modules.maps.services import routing
from app.shared.context import GeoLocation

ORIGIN = GeoLocation(latitude=-37.8177, longitude=144.9691)
DESTINATION = GeoLocation(latitude=-37.8102, longitude=144.9628)

# cut down version of a real OSRM reply. metres, seconds, and [lon, lat]
OSRM_OK = {
    "code": "Ok",
    "routes": [
        {
            "distance": 2614.8,
            "duration": 342.9,
            "geometry": {"coordinates": [[144.968825, -37.817114], [144.9628, -37.8102]]},
        },
        {
            "distance": 2558.8,
            "duration": 400.0,
            "geometry": {"coordinates": [[144.968825, -37.817114]]},
        },
    ],
}


@respx.mock
async def test_driving_uses_osrm_duration():
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json=OSRM_OK)
    )

    options = await routing.plan_routes(ORIGIN, DESTINATION, "driving")

    assert len(options) == 2
    fastest = options[0]
    assert fastest["summary"] == "Fastest route"
    assert fastest["distance_km"] == 2.61  # 2614.8 m
    assert fastest["eta_minutes"] == 6  # 342.9 s
    assert fastest["eta_is_estimated"] is False
    assert len(fastest["geometry"]) == 2


@respx.mock
async def test_options_are_sorted_fastest_first():
    """OSRM doesn't sort them, so we do it ourselves."""
    reversed_routes = {"code": "Ok", "routes": list(reversed(OSRM_OK["routes"]))}
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json=reversed_routes)
    )

    options = await routing.plan_routes(ORIGIN, DESTINATION, "driving")

    assert options[0]["eta_minutes"] <= options[1]["eta_minutes"]
    assert options[0]["summary"] == "Fastest route"
    assert options[1]["summary"] == "Alternative 1"


@respx.mock
async def test_each_mode_asks_its_own_server():
    """Walking and cycling need their own profile server, not the car one.

    The old project-osrm demo server only had the car profile and quietly
    returned car times for everything, which is why we moved to FOSSGIS.
    """
    route = respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json=OSRM_OK)
    )

    for mode, expected in (
        ("driving", "routed-car"),
        ("walking", "routed-foot"),
        ("cycling", "routed-bike"),
    ):
        route.reset()
        await routing.plan_routes(ORIGIN, DESTINATION, mode)
        assert expected in str(route.calls[0].request.url)


@respx.mock
async def test_times_come_from_the_router_not_a_guess():
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json=OSRM_OK)
    )

    options = await routing.plan_routes(ORIGIN, DESTINATION, "walking")

    # 342.9 seconds, straight from the reply
    assert options[0]["eta_minutes"] == 6
    assert options[0]["eta_is_estimated"] is False


def test_instructions_read_like_english():
    cases = [
        ({"type": "turn", "modifier": "right"}, "Queen Street", "Turn right onto Queen Street"),
        ({"type": "depart", "modifier": "left"}, "Flinders Street", "Start on Flinders Street"),
        ({"type": "arrive", "modifier": "left"}, "La Trobe Street", "Arrive at your destination"),
        (
            {"type": "turn", "modifier": "slight left"},
            "Elizabeth Street",
            "Turn slightly left onto Elizabeth Street",
        ),
    ]
    for maneuver, road, expected in cases:
        assert routing.describe_step({"maneuver": maneuver, "name": road}) == expected


def test_a_uturn_is_called_a_uturn():
    """OSRM calls this "continue uturn", which nobody would say out loud."""
    step = {"maneuver": {"type": "continue", "modifier": "uturn"}, "name": "La Trobe Street"}

    assert routing.describe_step(step) == "Make a U-turn on La Trobe Street"


def test_step_without_a_road_name_still_reads_ok():
    step = {"maneuver": {"type": "fork", "modifier": "left"}, "name": ""}

    assert routing.describe_step(step) == "Keep left"


def test_build_steps_pulls_out_every_turn():
    route = {
        "legs": [
            {
                "steps": [
                    {"maneuver": {"type": "depart"}, "name": "Flinders Street", "distance": 583.4},
                    {
                        "maneuver": {"type": "turn", "modifier": "right"},
                        "name": "Queen Street",
                        "distance": 949.2,
                    },
                ]
            }
        ]
    }

    steps = routing.build_steps(route)

    assert len(steps) == 2
    assert steps[0]["distance_m"] == 583
    assert steps[1]["instruction"] == "Turn right onto Queen Street"
    assert steps[1]["road"] == "Queen Street"


@respx.mock
async def test_routes_include_the_directions():
    with_steps = {
        "code": "Ok",
        "routes": [
            {
                "distance": 2614.8,
                "duration": 342.9,
                "geometry": {"coordinates": [[144.96, -37.81]]},
                "legs": [
                    {
                        "steps": [
                            {
                                "maneuver": {"type": "turn", "modifier": "right"},
                                "name": "Queen Street",
                                "distance": 949.2,
                            }
                        ]
                    }
                ],
            }
        ],
    }
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json=with_steps)
    )

    options = await routing.plan_routes(ORIGIN, DESTINATION, "driving")

    assert options[0]["steps"][0]["instruction"] == "Turn right onto Queen Street"


@respx.mock
async def test_no_route_raises_routing_error():
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json={"code": "NoRoute", "message": "no route"})
    )

    with pytest.raises(routing.RoutingError):
        await routing.plan_routes(ORIGIN, DESTINATION, "driving")


@respx.mock
async def test_empty_route_list_raises_routing_error():
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json={"code": "Ok", "routes": []})
    )

    with pytest.raises(routing.RoutingError):
        await routing.plan_routes(ORIGIN, DESTINATION, "driving")
