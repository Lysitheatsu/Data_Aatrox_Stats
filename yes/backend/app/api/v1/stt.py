"""
stt.py

FastAPI Speech-to-Text router with dual-engine support:
  1. PRIMARY  — Sherpa-ONNX SenseVoice CTC (on-device, fully offline, zero latency)
  2. FALLBACK — Groq whisper-large-v3-turbo (cloud, highest accuracy)

Adapted from:
  sherpa-onnx/python-api-examples/offline-sense-voice-ctc-decode-files.py
  sherpa-onnx/python-api-examples/offline-sense-voice-ctc-decode-files-with-hr.py

Endpoints:
  POST /v1/stt/transcribe         — Sherpa-ONNX SenseVoice (primary)
  POST /v1/stt/transcribe/groq    — Groq Whisper (fallback / cloud)
  POST /v1/stt/transcribe/auto    — Auto: tries Sherpa first, falls back to Groq
  GET  /v1/stt/status             — Engine availability status
"""

import asyncio
import httpx
from fastapi import APIRouter, File, Form, UploadFile, HTTPException
from typing import Optional

from app.core.config import settings
from app.core.logging import logger
from app.services.sherpa_stt_service import sherpa_stt_service

router = APIRouter(prefix="/stt", tags=["Speech-to-Text"])


# ── 1. Sherpa-ONNX SenseVoice (Primary – Offline) ───────────────────────────

@router.post("/transcribe")
async def transcribe_sherpa(file: UploadFile = File(...)):
    """
    Primary STT endpoint using Sherpa-ONNX SenseVoice CTC.

    Adapted from offline-sense-voice-ctc-decode-files.py:
      recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
          model=model, tokens=tokens, use_itn=True
      )
      stream = recognizer.create_stream()
      stream.accept_waveform(sample_rate, audio)
      recognizer.decode_stream(stream)
      text = stream.result.text

    Accepts:
      - WAV file (Content-Type: audio/wav or audio/x-wav)
      - Raw PCM bytes (Content-Type: audio/pcm)

    Returns:
      { text, language, emotion, confidence, inference_ms, engine }
    """
    if not sherpa_stt_service.is_available:
        raise HTTPException(
            status_code=503,
            detail=(
                "Sherpa-ONNX SenseVoice is not available. "
                "Check SHERPA_SENSE_VOICE_MODEL and SHERPA_SENSE_VOICE_TOKENS in backend/.env. "
                "Use /v1/stt/transcribe/groq as fallback."
            ),
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    content_type = (file.content_type or "").lower()

    # Run blocking inference in a thread pool so we don't block the event loop
    loop = asyncio.get_event_loop()

    if "pcm" in content_type:
        result = await loop.run_in_executor(
            None, sherpa_stt_service.transcribe_pcm_bytes, content, 16000
        )
    else:
        # Default: treat as WAV (matches both audio/wav and audio/x-wav)
        result = await loop.run_in_executor(
            None, sherpa_stt_service.transcribe_wav_bytes, content
        )

    logger.info(
        f"STT /transcribe: engine=sherpa-sense-voice "
        f"text='{result.text}' conf={result.confidence} ms={result.inference_ms}"
    )
    return result.to_dict()


# ── 2. Groq Whisper (Fallback – Cloud) ──────────────────────────────────────

@router.post("/transcribe/groq")
async def transcribe_groq(file: UploadFile = File(...)):
    """
    Fallback STT endpoint using Groq whisper-large-v3-turbo.

    Requires GROQ_API_KEY in backend/.env.
    Use when Sherpa-ONNX is unavailable or for highest accuracy.
    """
    if not settings.GROQ_API_KEY:
        raise HTTPException(
            status_code=503,
            detail="GROQ_API_KEY is not configured in backend/.env.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    try:
        files = {
            "file": (file.filename or "audio.wav", content, file.content_type or "audio/wav")
        }
        data = {"model": "whisper-large-v3-turbo", "response_format": "json"}
        headers = {"Authorization": f"Bearer {settings.GROQ_API_KEY}"}

        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                "https://api.groq.com/openai/v1/audio/transcriptions",
                headers=headers,
                data=data,
                files=files,
            )

        if response.status_code == 200:
            result = response.json()
            text = (result.get("text") or "").strip()
            logger.info(f"STT /transcribe/groq: text='{text}'")
            return {
                "text": text,
                "confidence": 0.95,
                "engine": "whisper-large-v3-turbo",
                "inference_ms": 0,
            }

        logger.error(f"STT Groq API Error {response.status_code}: {response.text}")
        raise HTTPException(status_code=502, detail=f"Groq API error: {response.text}")

    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"STT /transcribe/groq exception: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ── 3. Auto (Sherpa → Groq fallback) ────────────────────────────────────────

@router.post("/transcribe/auto")
async def transcribe_auto(file: UploadFile = File(...)):
    """
    Smart auto-routing endpoint.

    Tries Sherpa-ONNX SenseVoice first (offline, fast).
    Falls back to Groq Whisper if Sherpa returns empty or is unavailable.
    """
    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    result_dict: dict = {}

    # ── Try Sherpa first ────────────────────────────────────────────────────
    if sherpa_stt_service.is_available:
        loop = asyncio.get_event_loop()
        content_type = (file.content_type or "").lower()

        if "pcm" in content_type:
            result = await loop.run_in_executor(
                None, sherpa_stt_service.transcribe_pcm_bytes, content, 16000
            )
        else:
            result = await loop.run_in_executor(
                None, sherpa_stt_service.transcribe_wav_bytes, content
            )

        if result.text.strip():
            logger.info(f"STT /auto: Sherpa success -> '{result.text}'")
            return result.to_dict()

        logger.info("STT /auto: Sherpa returned empty text. Falling back to Groq Whisper.")

    # ── Fall back to Groq ───────────────────────────────────────────────────
    if settings.GROQ_API_KEY:
        try:
            files = {
                "file": (file.filename or "audio.wav", content, file.content_type or "audio/wav")
            }
            data = {"model": "whisper-large-v3-turbo", "response_format": "json"}
            headers = {"Authorization": f"Bearer {settings.GROQ_API_KEY}"}

            async with httpx.AsyncClient(timeout=15.0) as client:
                response = await client.post(
                    "https://api.groq.com/openai/v1/audio/transcriptions",
                    headers=headers,
                    data=data,
                    files=files,
                )

            if response.status_code == 200:
                groq_result = response.json()
                text = (groq_result.get("text") or "").strip()
                logger.info(f"STT /auto: Groq fallback -> '{text}'")
                return {"text": text, "confidence": 0.95, "engine": "whisper-large-v3-turbo", "inference_ms": 0}

        except Exception as e:
            logger.error(f"STT /auto: Groq fallback exception: {e}")

    return {"text": "", "confidence": 0.0, "engine": "none", "inference_ms": 0}


# ── 4. Status ────────────────────────────────────────────────────────────────

@router.get("/status")
async def stt_status():
    """
    Returns the availability status of both STT engines.
    """
    return {
        "sherpa_sense_voice": {
            "available": sherpa_stt_service.is_available,
            "model": settings.SHERPA_SENSE_VOICE_MODEL,
            "engine": "sherpa-onnx-sense-voice-ctc",
        },
        "groq_whisper": {
            "available": bool(settings.GROQ_API_KEY),
            "model": "whisper-large-v3-turbo",
            "engine": "groq-cloud",
        },
    }

