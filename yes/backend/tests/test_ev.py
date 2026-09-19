"""Tests for the EV charging stop planner."""

from __future__ import annotations

import httpx
import respx

from app.modules.maps.services import ev, places

ROUTE = [[144.96 + i * 0.01, -37.81 - i * 0.01] for i in range(100)]


def test_a_short_trip_needs_no_charging():
    """75km on a 350km car is nothing."""
    assert ev.stops_needed(75) == 0


def test_you_dont_run_it_to_empty():
    """You keep a bit in reserve, so usable range is less than 350."""
    assert ev.usable_range(350) == 297.5
    assert ev.stops_needed(290) == 0
    assert ev.stops_needed(320) == 1


def test_a_long_trip_needs_more_than_one_stop():
    """Melbourne to Sydney, about 880km."""
    assert ev.stops_needed(880) == 2


def test_a_smaller_car_stops_more_often():
    assert ev.stops_needed(400, range_km=200) > ev.stops_needed(400, range_km=500)


def test_stop_points_land_on_the_route():
    points = ev.stop_points(ROUTE, 880)

    assert len(points) == 2
    for point in points:
        assert point in ROUTE


def test_no_stops_means_no_points():
    assert ev.stop_points(ROUTE, 50) == []


@respx.mock
async def test_a_short_trip_returns_early():
    """Don't search for chargers you don't need."""
    route = respx.post(places.OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )

    plan = await ev.charging_plan(ROUTE, 60)

    assert plan["stops_needed"] == 0
    assert plan["chargers"] == []
    assert not route.called


@respx.mock
async def test_a_long_trip_looks_for_chargers():
    respx.post(places.OVERPASS_URL).mock(
        return_value=httpx.Response(
            200,
            json={
                "elements": [
                    {
                        "type": "node",
                        "lat": -38.0,
                        "lon": 144.5,
                        "tags": {"name": "Ballarat Supercharger"},
                    }
                ]
            },
        )
    )

    plan = await ev.charging_plan(ROUTE, 500)

    assert plan["stops_needed"] == 1
    assert plan["chargers"][0]["name"] == "Ballarat Supercharger"
    assert plan["assumed_range_km"] == ev.DEFAULT_RANGE_KM
