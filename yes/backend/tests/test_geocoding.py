"""Tests for the search service.

The fake responses are cut down copies of what Nominatim really sent back.
"""

from __future__ import annotations

import httpx
import pytest
import respx

from app.modules.maps.services import geocoding

SEARCH_RESULT = [
    {
        "place_id": 22210942,
        "osm_type": "way",
        "lat": "-37.8177396",
        "lon": "144.9691559",
        "name": "Federation Square",
        "display_name": "Federation Square, Melbourne, Victoria, Australia",
    }
]


@respx.mock
async def test_search_returns_locations():
    respx.get(geocoding.SEARCH_URL).mock(
        return_value=httpx.Response(200, json=SEARCH_RESULT)
    )

    results = await geocoding.search("Federation Square")

    assert len(results) == 1
    assert results[0].label == "Federation Square"
    # Nominatim sends these as text, they should come out as numbers
    assert results[0].latitude == pytest.approx(-37.8177396)
    assert results[0].longitude == pytest.approx(144.9691559)


@respx.mock
async def test_search_falls_back_to_display_name():
    """Some results have no short name, so fall back to the long one."""
    respx.get(geocoding.SEARCH_URL).mock(
        return_value=httpx.Response(
            200,
            json=[{"lat": "1.0", "lon": "2.0", "display_name": "Somewhere long"}],
        )
    )

    results = await geocoding.search("somewhere")

    assert results[0].label == "Somewhere long"


@respx.mock
async def test_search_with_no_matches():
    respx.get(geocoding.SEARCH_URL).mock(return_value=httpx.Response(200, json=[]))

    assert await geocoding.search("qwertyuiop") == []


@respx.mock
async def test_reverse_returns_none_on_error_payload():
    """It sends an error in the body instead of a 404."""
    respx.get(geocoding.REVERSE_URL).mock(
        return_value=httpx.Response(200, json={"error": "Unable to geocode"})
    )

    assert await geocoding.reverse(0.0, 0.0) is None


@respx.mock
async def test_upstream_failure_raises():
    respx.get(geocoding.SEARCH_URL).mock(return_value=httpx.Response(429))

    with pytest.raises(httpx.HTTPError):
        await geocoding.search("anything")
