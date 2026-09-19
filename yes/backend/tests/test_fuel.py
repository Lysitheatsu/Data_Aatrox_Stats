"""Tests for the fuel cost estimate."""

from __future__ import annotations

from app.modules.maps.services import fuel


def test_petrol_cost_for_a_known_trip():
    """100 km at 8L/100km and $1.85/L = 8 litres, $14.80."""
    result = fuel.petrol_cost(100)

    assert result["litres"] == 8.0
    assert result["cost"] == 14.8
    assert result["unit"] == "L"


def test_ev_is_cheaper_than_petrol():
    """True with the numbers we default to."""
    assert fuel.ev_cost(100)["cost"] < fuel.petrol_cost(100)["cost"]


def test_the_assumptions_come_back_too():
    """The app needs to show what we assumed."""
    result = fuel.petrol_cost(50)

    assert result["consumption_per_100km"] == fuel.DEFAULT_CONSUMPTION
    assert result["price_per_unit"] == fuel.DEFAULT_PRICE_PER_LITRE


def test_you_can_pass_your_own_numbers():
    """A thirsty car and expensive fuel."""
    result = fuel.petrol_cost(100, litres_per_100km=12.0, price_per_litre=2.20)

    assert result["litres"] == 12.0
    assert result["cost"] == 26.4


def test_a_zero_length_trip_costs_nothing():
    assert fuel.petrol_cost(0)["cost"] == 0.0


def test_ev_has_no_litres():
    """EVs use kWh, so litres should be empty not 0."""
    assert fuel.ev_cost(100)["litres"] is None
    assert fuel.ev_cost(100)["unit"] == "kWh"
