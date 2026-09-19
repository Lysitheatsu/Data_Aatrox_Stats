"""
emergency_phrase_parser.py

Emergency transcript intent classification & phrase parsing module.
"""

import re
from typing import Tuple, List

EMERGENCY_KEYWORDS = {
    "HELP_EMERGENCY": ["help", "sos", "save me", "danger", "attack", "robbery"],
    "CRITICAL_MEDICAL_ASSISTANCE": ["can't breathe", "breathe", "chest pain", "bleeding", "stroke", "unconscious", "ambulance", "hospital"],
    "ACCIDENT": ["accident", "crash", "hit", "trapped", "collision"],
    "FIRE": ["fire", "smoke", "burning", "explosion"],
    "CANCEL_SOS": ["false alarm", "i'm safe", "cancel", "stop", "nevermind"]
}


def parse_transcript_intent(transcript_text: str) -> Tuple[str, float, List[str]]:
    text = (transcript_text or "").lower().strip()
    if not text:
        return ("UNKNOWN", 0.0, [])

    matched_keywords = []
    best_intent = "UNKNOWN"
    best_confidence = 0.50

    for intent, keywords in EMERGENCY_KEYWORDS.items():
        for kw in keywords:
            if re.search(r"\b" + re.escape(kw) + r"\b", text):
                matched_keywords.append(kw)
                if best_intent == "UNKNOWN" or intent == "CRITICAL_MEDICAL_ASSISTANCE":
                    best_intent = intent
                    best_confidence = 0.95 if intent != "CANCEL_SOS" else 0.99

    if not matched_keywords:
        best_intent = "HELP_EMERGENCY" if "help" in text else "UNKNOWN"
        best_confidence = 0.70 if best_intent != "UNKNOWN" else 0.30

    return (best_intent, best_confidence, matched_keywords)
