"""Tests for the Overpass nearby-places service."""

from __future__ import annotations

import httpx
import pytest
import respx

from app.modules.maps.services import places

# Fed Square-ish
LAT, LON = -37.8177, 144.9691

# nodes have lat/lon, ways have a "center" instead
OVERPASS_REPLY = {
    "elements": [
        {
            "type": "way",
            "center": {"lat": -37.8068, "lon": 144.9747},
            "tags": {"name": "St Vincent's Hospital"},
        },
        {
            "type": "node",
            "lat": -37.8171,
            "lon": 144.9930,
            "tags": {"name": "Epworth Richmond Hospital"},
        },
        # no name, should get skipped
        {"type": "node", "lat": -37.81, "lon": 144.96, "tags": {}},
        # no coordinates, should also get skipped
        {"type": "way", "tags": {"name": "Ghost Hospital"}},
    ]
}


def test_every_spec_category_has_an_osm_tag():
    """Every category in the spec needs an OSM tag or /nearby breaks."""
    expected = {
        "restaurants",
        "hospitals",
        "pharmacies",
        "petrol_stations",
        "parking",
        "charging_stations",
        "hotels",
        "attractions",
    }

    assert set(places.CATEGORY_TAGS) == expected
    for key, value in places.CATEGORY_TAGS.values():
        assert key and value


def test_unknown_category_raises():
    with pytest.raises(places.UnknownCategory):
        places.build_query("unicorns", LAT, LON, 2000)


def test_query_contains_the_right_tag_and_radius():
    query = places.build_query("charging_stations", LAT, LON, 1500)

    assert '"amenity"="charging_station"' in query
    assert "around:1500" in query
    # without "out center" the ways come back with no coordinates
    assert "out center" in query


def test_distance_is_roughly_right():
    """CBD to Richmond is about 2 km."""
    result = places.distance_km(-37.8177, 144.9691, -37.8171, 144.9930)

    assert 1.9 < result < 2.3


def test_distance_to_itself_is_zero():
    assert places.distance_km(LAT, LON, LAT, LON) == 0.0


@respx.mock
async def test_nearby_skips_unusable_results_and_sorts_by_distance():
    respx.post(places.OVERPASS_URL).mock(
        return_value=httpx.Response(200, json=OVERPASS_REPLY)
    )

    results = await places.nearby("hospitals", LAT, LON)

    # the unnamed one and the one with no coordinates should be gone
    names = [r["name"] for r in results]
    assert names == ["St Vincent's Hospital", "Epworth Richmond Hospital"]
    assert results[0]["distance_km"] <= results[1]["distance_km"]
    assert results[0]["category"] == "hospitals"


@respx.mock
async def test_nearby_with_nothing_found():
    respx.post(places.OVERPASS_URL).mock(
        return_value=httpx.Response(200, json={"elements": []})
    )

    assert await places.nearby("hotels", LAT, LON) == []
