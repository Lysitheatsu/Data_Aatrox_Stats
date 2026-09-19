"""Tests for the /maps endpoints.

These go through the actual app with the OSM servers mocked, so they check
the status codes and validation that the service tests don't.
"""

from __future__ import annotations

import httpx
import respx
from fastapi.testclient import TestClient

from app.main import app
from app.modules.maps.services import geocoding, journey, places, routing

client = TestClient(app)

MELBOURNE = {"latitude": -37.8177, "longitude": 144.9691}
ROUTE_BODY = {
    "origin": MELBOURNE,
    "destination": {"latitude": -37.8102, "longitude": 144.9628},
    "mode": "driving",
}

OSRM_OK = {
    "code": "Ok",
    "routes": [
        {
            "distance": 2614.8,
            "duration": 342.9,
            "geometry": {"coordinates": [[144.96, -37.81]]},
        }
    ],
}


def test_development_cors_allows_remote_expo_origin():
    response = client.options(
        "/maps/search?q=test",
        headers={
            "Origin": "http://100.64.10.20:8081",
            "Access-Control-Request-Method": "GET",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://100.64.10.20:8081"


@respx.mock
def test_search_returns_results():
    respx.get(geocoding.SEARCH_URL).mock(
        return_value=httpx.Response(
            200,
            json=[{"lat": "-37.8177", "lon": "144.9691", "name": "Federation Square"}],
        )
    )

    response = client.get("/maps/search", params={"q": "Federation Square"})

    assert response.status_code == 200
    assert response.json()[0]["label"] == "Federation Square"


def test_search_needs_a_query():
    assert client.get("/maps/search").status_code == 422


@respx.mock
def test_search_turns_an_upstream_failure_into_502():
    """A broken service should come back as our error, not httpx's."""
    respx.get(geocoding.SEARCH_URL).mock(return_value=httpx.Response(500))

    response = client.get("/maps/search", params={"q": "anything"})

    assert response.status_code == 502
    assert "unavailable" in response.json()["detail"].lower()


@respx.mock
def test_routes_returns_options_with_geometry():
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json=OSRM_OK)
    )

    response = client.post("/maps/routes", json=ROUTE_BODY)

    assert response.status_code == 200
    body = response.json()
    assert body["mode"] == "driving"
    assert body["options"][0]["distance_km"] == 2.61
    assert body["options"][0]["geometry"] == [[144.96, -37.81]]


@respx.mock
def test_unroutable_points_return_422_not_502():
    """OSRM worked fine, it just can't route it, so not a 502."""
    respx.get(url__startswith=routing.BASE_URL).mock(
        return_value=httpx.Response(200, json={"code": "NoRoute", "message": "no route"})
    )

    response = client.post("/maps/routes", json=ROUTE_BODY)

    assert response.status_code == 422


@respx.mock
def test_nearby_returns_places():
    respx.post(places.OVERPASS_URL).mock(
        return_value=httpx.Response(
            200,
            json={
                "elements": [
                    {
                        "type": "node",
                        "lat": -37.8171,
                        "lon": 144.9930,
                        "tags": {"name": "Epworth Richmond"},
                    }
                ]
            },
        )
    )

    response = client.get("/maps/nearby", params={"category": "hospitals", **MELBOURNE})

    assert response.status_code == 200
    assert response.json()[0]["name"] == "Epworth Richmond"


def test_unknown_category_returns_400_and_lists_valid_ones():
    response = client.get("/maps/nearby", params={"category": "unicorns", **MELBOURNE})

    assert response.status_code == 400
    assert "hospitals" in response.json()["detail"]


def test_nearby_rejects_impossible_coordinates():
    response = client.get(
        "/maps/nearby",
        params={"category": "hospitals", "latitude": 999, "longitude": 0},
    )

    assert response.status_code == 422


@respx.mock
def test_journey_info_returns_real_conditions():
    respx.get(journey.FORECAST_URL).mock(
        return_value=httpx.Response(
            200, json={"current": {"temperature_2m": 10.0, "weather_code": 1}}
        )
    )
    respx.get(journey.AIR_QUALITY_URL).mock(
        return_value=httpx.Response(200, json={"current": {"us_aqi": 37}})
    )

    response = client.post("/maps/journey-info", json=ROUTE_BODY)

    assert response.status_code == 200
    body = response.json()
    assert body["weather_summary"] == "Mainly clear, 10°C"
    assert body["air_quality_index"] == 37
    # no traffic data, so this should be null not a made up number
    assert body["traffic_delay_minutes"] is None
