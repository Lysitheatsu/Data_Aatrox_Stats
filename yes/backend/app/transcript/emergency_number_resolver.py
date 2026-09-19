"""
emergency_number_resolver.py

Utility helper that resolves national emergency numbers based on country code.
"""

EMERGENCY_NUMBERS = {
    "IN": "112",
    "US": "911",
    "CA": "911",
    "GB": "999",
    "UK": "999",
    "AU": "000",
    "NZ": "111",
    "JP": "110",
    "CN": "110",
    "KR": "112",
    "SG": "999",
    "AE": "999",
    "BR": "190",
    "MX": "911",
    "ZA": "112",
    "DE": "112",
    "FR": "112",
    "IT": "112",
    "ES": "112",
    "NL": "112",
    "SE": "112",
    "NO": "112",
    "CH": "112",
    "AT": "112",
    "BE": "112",
    "DK": "112",
    "FI": "112",
    "IE": "112",
    "PT": "112",
    "GR": "112",
    "PL": "112",
    "RU": "112",
    "TR": "112"
}


def resolve_emergency_number(country_code: str) -> str:
    code = (country_code or "IN").upper()
    return EMERGENCY_NUMBERS.get(code, "112")
