"""Module 4 — ELLY AI Travel Assistant.

The conversational, proactive assistant that understands the user's travel
context. V1 stubs below. Wire `chat` to an LLM provider (see the recommended
models in SPECIFICATION.md) and feed it the shared user context.
"""

from __future__ import annotations

from enum import Enum

from fastapi import APIRouter
from pydantic import BaseModel

router = APIRouter(prefix="/assistant", tags=["ELLY AI Travel Assistant"])


class SuggestionType(str, Enum):
    leave_earlier = "leave_earlier"
    traffic = "traffic"
    weather = "weather"
    appointment = "appointment"
    parking = "parking"
    route = "route"


class Suggestion(BaseModel):
    type: SuggestionType
    title: str
    detail: str


@router.get("/suggestions", response_model=list[Suggestion])
async def smart_suggestions(user_id: str) -> list[Suggestion]:
    """Proactive smart suggestions for the user (stub)."""
    return [
        Suggestion(
            type=SuggestionType.leave_earlier,
            title="Leave for work now",
            detail="Heavy traffic on Western Hwy. Save 12 min via MCG Rd.",
        ),
        Suggestion(
            type=SuggestionType.weather,
            title="Rain expected in 30 min",
            detail="Carry an umbrella.",
        ),
    ]


class ChatRequest(BaseModel):
    user_id: str
    message: str


class ChatResponse(BaseModel):
    reply: str


@router.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    """Conversational, context-aware assistant (stub).

    Replace with a real LLM call that grounds responses in the shared user
    context and live map/journey data.
    """
    return ChatResponse(
        reply=(
            "Hi! I'm ELLY. Once connected to an LLM I'll answer travel "
            f"questions like: '{request.message}'."
        )
    )
