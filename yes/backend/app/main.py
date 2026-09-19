"""ELLY Maps API — application entrypoint.

Wires the four intelligence modules (Maps, Connections, Emergency, ELLY AI)
onto a single FastAPI app. They share the unified user context in
`app.shared.context`.

Run locally:
    uvicorn app.main:app --reload
Then open http://localhost:8000/docs
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import get_settings
from app.core.logging import logger
from app.database.session import engine, Base
from app.modules.assistant.router import router as assistant_router
from app.modules.connections.router import router as connections_router
from app.modules.emergency.router import router as emergency_router
from app.modules.maps.router import router as maps_router

from app.api.v1.assistant import router as sos_assistant_router
from app.api.v1.auth import router as auth_router
from app.api.v1.emergency import router as sos_emergency_router
from app.api.v1.health_passport import router as health_passport_router
from app.api.v1.responders import router as responders_router
from app.api.v1.sos_circle import router as sos_circle_router
from app.api.v1.speaker import router as speaker_router
from app.api.v1.stt import router as stt_router
from app.api.v1.telemetry import router as telemetry_router
from app.api.v1.websocket import router as ws_router
from app.services.sherpa_stt_service import sherpa_stt_service
from app.services.speaker_verification_service import speaker_verification_service

settings = get_settings()


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Initializing ELLY Maps and SOS Backend...")

    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    logger.info("Database tables initialized successfully.")

    import asyncio

    loop = asyncio.get_event_loop()

    ok = await loop.run_in_executor(None, sherpa_stt_service.initialize)
    if ok:
        logger.info("Sherpa-ONNX SenseVoice CTC ready.")
    else:
        logger.warning("Sherpa-ONNX SenseVoice not available. Groq Whisper fallback active.")

    sv_ok = await loop.run_in_executor(None, speaker_verification_service.initialize)
    if sv_ok:
        logger.info("Sherpa-ONNX speaker verification ready.")
    else:
        logger.warning("Sherpa-ONNX speaker verification not available.")

    yield

    logger.info("Shutting down ELLY Maps and SOS Backend...")


app = FastAPI(
    title=settings.app_name,
    version="0.1.0",
    description=(
        "AI-powered mobility intelligence platform. See "
        "reference/SPECIFICATION.md for the product vision."
    ),
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# The four major systems, each behind its own prefix.
app.include_router(maps_router)
app.include_router(connections_router)
app.include_router(emergency_router)
app.include_router(assistant_router)

# SOS Emergency backend.
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(sos_emergency_router, prefix=settings.API_V1_STR)
app.include_router(health_passport_router, prefix=settings.API_V1_STR)
app.include_router(sos_circle_router, prefix=settings.API_V1_STR)
app.include_router(responders_router, prefix=settings.API_V1_STR)
app.include_router(telemetry_router, prefix=settings.API_V1_STR)
app.include_router(sos_assistant_router, prefix=settings.API_V1_STR)
app.include_router(stt_router, prefix=settings.API_V1_STR)
app.include_router(speaker_router, prefix=settings.API_V1_STR)
app.include_router(ws_router)


@app.get("/health", tags=["System"])
async def health() -> dict[str, str]:
    """Liveness probe."""
    return {"status": "ok", "environment": settings.environment}
