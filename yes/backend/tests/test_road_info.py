"""Tests for the toll roads and roadworks lookup."""

from __future__ import annotations

import httpx
import respx

from app.modules.maps.services import road_info

# fake route, [lon, lat] like OSRM gives us
ROUTE = [[144.96 + i * 0.01, -37.81 - i * 0.01] for i in range(100)]

OVERPASS_REPLY = {
    "elements": [
        {"type": "way", "tags": {"name": "CityLink", "toll": "yes", "highway": "motorway"}},
        {"type": "way", "tags": {"name": "EastLink", "toll": "yes", "highway": "motorway"}},
        # same road twice, should only show once
        {"type": "way", "tags": {"name": "CityLink", "toll": "yes", "highway": "motorway"}},
        {"type": "way", "tags": {"name": "Kane's Bridge", "highway": "construction"}},
        # no name, skip it
        {"type": "way", "tags": {"toll": "yes", "highway": "motorway_link"}},
    ]
}


def test_a_long_route_gets_thinned_down():
    """1000 points is too many for one query."""
    sampled = road_info.sample_route(ROUTE)

    assert len(sampled) <= road_info.SAMPLE_POINTS + 1
    assert sampled[0] == ROUTE[0]


def test_a_short_route_is_left_alone():
    short = ROUTE[:5]

    assert road_info.sample_route(short) == short


def test_an_empty_route_gives_nothing():
    assert road_info.sample_route([]) == []


@respx.mock
async def test_finds_tolls_and_roadworks():
    respx.post(road_info.OVERPASS_URL).mock(
        return_value=httpx.Response(200, json=OVERPASS_REPLY)
    )

    found = await road_info.road_info(ROUTE)

    # no duplicates, no unnamed ones
    assert found["toll_roads"] == ["CityLink", "EastLink"]
    assert found["construction"] == ["Kane's Bridge"]


@respx.mock
async def test_no_route_means_no_query():
    """No route, no point asking."""
    route = respx.post(road_info.OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )

    found = await road_info.road_info([])

    assert found == {"toll_roads": [], "construction": []}
    assert not route.called


@respx.mock
async def test_a_clear_route_reports_nothing():
    respx.post(road_info.OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )

    found = await road_info.road_info(ROUTE)

    assert found["toll_roads"] == []
    assert found["construction"] == []
