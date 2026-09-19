"""Weather and air quality for a trip.

Open-Meteo is free and needs no API key. Weather and air quality are two
separate endpoints so we call both and join them up.

The weather comes back as a number (a WMO code) so WEATHER_CODES turns it
into words.
"""

from __future__ import annotations

from app.shared.context import GeoLocation

from .http import fetch_json

FORECAST_URL = "https://api.open-meteo.com/v1/forecast"
AIR_QUALITY_URL = "https://air-quality-api.open-meteo.com/v1/air-quality"

# the codes you actually see day to day, full list is in the Open-Meteo docs
WEATHER_CODES: dict[int, str] = {
    0: "Clear",
    1: "Mainly clear",
    2: "Partly cloudy",
    3: "Overcast",
    45: "Fog",
    48: "Freezing fog",
    51: "Light drizzle",
    53: "Drizzle",
    55: "Heavy drizzle",
    61: "Light rain",
    63: "Rain",
    65: "Heavy rain",
    71: "Light snow",
    73: "Snow",
    75: "Heavy snow",
    80: "Light showers",
    81: "Showers",
    82: "Heavy showers",
    95: "Thunderstorm",
    96: "Thunderstorm with hail",
    99: "Severe thunderstorm",
}


def midpoint(origin: GeoLocation, destination: GeoLocation) -> tuple[float, float]:
    """Roughly the middle of the trip.

    Just averaging the two ends. Not perfect over long distances but fine
    for one weather reading.
    """
    return (
        (origin.latitude + destination.latitude) / 2,
        (origin.longitude + destination.longitude) / 2,
    )


def describe(code: int | None, temperature: float | None) -> str:
    """Turn the code and temperature into something like "Clear, 28°C"."""
    text = WEATHER_CODES.get(code, "Unknown") if code is not None else "Unknown"
    if temperature is None:
        return text
    return f"{text}, {round(temperature)}°C"


async def journey_conditions(
    origin: GeoLocation, destination: GeoLocation
) -> dict:
    """Get the weather and air quality halfway along the route."""
    latitude, longitude = midpoint(origin, destination)

    forecast = await fetch_json(
        FORECAST_URL,
        params={
            "latitude": latitude,
            "longitude": longitude,
            "current": "temperature_2m,weather_code",
            "timezone": "auto",
        },
    )
    air = await fetch_json(
        AIR_QUALITY_URL,
        params={
            "latitude": latitude,
            "longitude": longitude,
            "current": "us_aqi",
        },
    )

    current = forecast.get("current") or {}
    air_current = air.get("current") or {}

    return {
        "weather_summary": describe(
            current.get("weather_code"), current.get("temperature_2m")
        ),
        "air_quality_index": air_current.get("us_aqi"),
    }
