"""Tests for the Open-Meteo weather and air quality service."""

from __future__ import annotations

import httpx
import respx

from app.modules.maps.services import journey
from app.shared.context import GeoLocation

ORIGIN = GeoLocation(latitude=-38.0, longitude=144.0)
DESTINATION = GeoLocation(latitude=-37.0, longitude=145.0)

FORECAST = {"current": {"temperature_2m": 10.0, "weather_code": 1}}
AIR = {"current": {"us_aqi": 37}}


def test_midpoint_is_between_the_two_ends():
    lat, lon = journey.midpoint(ORIGIN, DESTINATION)

    assert lat == -37.5
    assert lon == 144.5


def test_describe_turns_a_code_into_words():
    assert journey.describe(0, 28.4) == "Clear, 28°C"
    assert journey.describe(61, 9.6) == "Light rain, 10°C"


def test_describe_handles_a_code_we_do_not_know():
    assert journey.describe(1234, 20.0) == "Unknown, 20°C"


def test_describe_without_a_temperature():
    assert journey.describe(0, None) == "Clear"


@respx.mock
async def test_journey_conditions_combines_both_endpoints():
    respx.get(journey.FORECAST_URL).mock(return_value=httpx.Response(200, json=FORECAST))
    respx.get(journey.AIR_QUALITY_URL).mock(return_value=httpx.Response(200, json=AIR))

    result = await journey.journey_conditions(ORIGIN, DESTINATION)

    assert result["weather_summary"] == "Mainly clear, 10°C"
    assert result["air_quality_index"] == 37


@respx.mock
async def test_missing_air_quality_is_none_not_a_crash():
    respx.get(journey.FORECAST_URL).mock(return_value=httpx.Response(200, json=FORECAST))
    respx.get(journey.AIR_QUALITY_URL).mock(
        return_value=httpx.Response(200, json={"current": {}})
    )

    result = await journey.journey_conditions(ORIGIN, DESTINATION)

    assert result["air_quality_index"] is None
    assert result["weather_summary"] == "Mainly clear, 10°C"
