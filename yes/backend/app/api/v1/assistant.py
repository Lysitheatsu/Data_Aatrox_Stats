"""
assistant.py

FastAPI router for optional Cloud AI Assistant (Groq LLaMA / OpenAI).
"""

from typing import List, Optional
from fastapi import APIRouter, Depends
from pydantic import BaseModel

from app.core.logging import logger
from app.services.assistant_service import assistant_service

router = APIRouter(prefix="/assistant", tags=["Cloud AI Assistant"])


class ChatMessage(BaseModel):
    role: str  # "system", "user", "assistant"
    content: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]
    user_id: Optional[str] = None
    temperature: float = 0.7


class ChatResponse(BaseModel):
    reply: str
    role: str = "assistant"


@router.post("/chat", response_model=ChatResponse)
async def assistant_chat(payload: ChatRequest):
    logger.info(f"Assistant chat request from user {payload.user_id}")
    msg_dicts = [{"role": m.role, "content": m.content} for m in payload.messages]
    reply_text = await assistant_service.generate_response(messages=msg_dicts)
    return ChatResponse(reply=reply_text)
