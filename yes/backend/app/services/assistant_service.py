"""
assistant_service.py

Comprehensive Cloud AI Assistant service for non-emergency guidance, LLM completions, and speech synthesis wrappers.
"""

from typing import List, Dict, Optional
import httpx
from app.core.config import settings
from app.core.logging import logger

SYSTEM_PROMPT = """
You are ELLY, a personal emergency & safety companion AI.
Your primary role is to assist users with safety guidance, health passport information, emergency contacts, and readiness checks.
If the user indicates a severe life-threatening emergency, immediately advise them to trigger the Red SOS Button or speak 'Help me emergency'.
Keep all answers concise, calm, direct, and reassuring.
"""


class AssistantService:
    def __init__(self, api_key: str = "", model: str = "llama-3.3-70b-versatile") -> None:
        self._api_key = api_key
        self._model = model

    async def generate_response(self, messages: List[Dict[str, str]], user_context: Optional[Dict] = None) -> str:
        if not self._api_key:
            # Fallback local response when Groq API key is not configured
            last_msg = messages[-1]["content"] if messages else ""
            return (
                f"ELLY Safety Companion: I have received your message regarding '{last_msg}'. "
                f"For immediate life-threatening emergencies, press the Red SOS Button to activate local offline dispatch."
            )

        try:
            formatted_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
            if user_context:
                context_str = f"User Health Context: Blood Group {user_context.get('blood_group')}, Allergies: {user_context.get('allergies')}"
                formatted_messages.append({"role": "system", "content": context_str})

            for msg in messages:
                formatted_messages.append({"role": msg["role"], "content": msg["content"]})

            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    "https://api.groq.com/openai/v1/chat/completions",
                    headers={
                        "Authorization": f"Bearer {self._api_key}",
                        "Content-Type": "application/json"
                    },
                    json={
                        "model": self._model,
                        "messages": formatted_messages,
                        "temperature": 0.5,
                        "max_tokens": 500
                    }
                )

                if response.status_code == 200:
                    data = response.json()
                    reply = data["choices"][0]["message"]["content"]
                    logger.info("AssistantService: Groq LLM completion successful.")
                    return reply
                else:
                    logger.error(f"AssistantService: Groq API Error {response.statusCode}: {response.text}")
                    return "ELLY Companion: Unable to connect to cloud assistant. Your local emergency protection remains active."

        except Exception as e:
            logger.error(f"AssistantService exception: {e}")
            return "ELLY Companion: Local emergency protection active."


assistant_service = AssistantService()
