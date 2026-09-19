"""
phone_normalizer.py

E.164 international phone number normalizer for Python FastAPI backend.
"""

import re

DIAL_CODES = {
    "IN": "+91",
    "US": "+1",
    "CA": "+1",
    "GB": "+44",
    "AU": "+61",
    "JP": "+81",
    "NZ": "+64",
    "SG": "+65",
    "BR": "+55",
    "MX": "+52"
}


def normalize_phone_number(raw_phone: str, default_country_code: str = "IN") -> str:
    if not raw_phone:
        return raw_phone

    cleaned = re.sub(r"[^\d+]", "", raw_phone)
    if not cleaned:
        return raw_phone

    if cleaned.startswith("+"):
        return cleaned

    dial_code = DIAL_CODES.get(default_country_code.upper(), "+91")
    trimmed_digits = re.sub(r"^0+", "", cleaned)
    return f"{dial_code}{trimmed_digits}"
