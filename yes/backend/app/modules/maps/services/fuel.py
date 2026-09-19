"""Roughly what a trip costs in fuel.

No free API does this, so we work it out from the distance and some average
numbers. It's an estimate, not a real price, so we send the numbers we used
back too.

Defaults are for an average petrol car in Australia. Prices change all the
time so this should come from user settings later.
"""

from __future__ import annotations

# litres per 100km for a normal petrol car
DEFAULT_CONSUMPTION = 8.0

# AUD per litre, rough average
DEFAULT_PRICE_PER_LITRE = 1.85

# same for an EV, and what power costs at home
DEFAULT_EV_CONSUMPTION = 17.0
DEFAULT_PRICE_PER_KWH = 0.30


def petrol_cost(
    distance_km: float,
    litres_per_100km: float = DEFAULT_CONSUMPTION,
    price_per_litre: float = DEFAULT_PRICE_PER_LITRE,
) -> dict:
    """Roughly what the fuel costs."""
    litres = distance_km * litres_per_100km / 100
    return {
        "cost": round(litres * price_per_litre, 2),
        "litres": round(litres, 2),
        # send these back so the app can show what we assumed
        "consumption_per_100km": litres_per_100km,
        "price_per_unit": price_per_litre,
        "unit": "L",
    }


def ev_cost(
    distance_km: float,
    kwh_per_100km: float = DEFAULT_EV_CONSUMPTION,
    price_per_kwh: float = DEFAULT_PRICE_PER_KWH,
) -> dict:
    """Same but for an EV."""
    kwh = distance_km * kwh_per_100km / 100
    return {
        "cost": round(kwh * price_per_kwh, 2),
        "litres": None,
        "consumption_per_100km": kwh_per_100km,
        "price_per_unit": price_per_kwh,
        "unit": "kWh",
    }
