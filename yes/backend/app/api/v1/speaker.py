"""
speaker.py

FastAPI Speaker Verification router with Sherpa-ONNX ECAPA-TDNN embeddings.

Endpoints:
  POST /v1/speaker/enroll          — Extract embedding from audio, store profile
  POST /v1/speaker/verify          — Extract embedding, compare against enrolled profile
  POST /v1/speaker/extract         — Extract embedding only (no storage)
  GET  /v1/speaker/profiles        — List enrolled profiles
  DELETE /v1/speaker/profiles/{id} — Delete a profile
  GET  /v1/speaker/status          — Engine availability status
"""

import asyncio
import uuid
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from typing import Optional

from app.core.logging import logger
from app.services.speaker_verification_service import speaker_verification_service

router = APIRouter(prefix="/speaker", tags=["Speaker Verification"])


# ── 1. Enroll — Upload audio, extract embedding, store profile ────────────

@router.post("/enroll")
async def enroll_speaker(
    file: UploadFile = File(...),
    display_name: str = Form(...),
    profile_id: Optional[str] = Form(default=None),
    is_primary: bool = Form(default=True),
):
    """
    Enroll a new speaker profile.

    Uploads a WAV/PCM audio file, extracts a 192-dim ECAPA-TDNN speaker
    embedding via Sherpa-ONNX, and stores the profile persistently.

    Returns:
      { profile_id, display_name, embedding_dim, inference_ms, engine }
    """
    if not speaker_verification_service.is_available:
        raise HTTPException(
            status_code=503,
            detail=(
                "Speaker verification engine not available. "
                "Set SHERPA_SPEAKER_MODEL in backend/.env and restart."
            ),
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    loop = asyncio.get_event_loop()
    content_type = (file.content_type or "").lower()

    if "pcm" in content_type:
        result = await loop.run_in_executor(
            None, speaker_verification_service.extract_embedding_from_pcm_bytes, content, 16000
        )
    else:
        result = await loop.run_in_executor(
            None, speaker_verification_service.extract_embedding_from_wav_bytes, content
        )

    if result is None or not result.embedding:
        raise HTTPException(
            status_code=422,
            detail="Could not extract speaker embedding from audio. Ensure non-silent speech.",
        )

    pid = profile_id or f"spk_{uuid.uuid4().hex[:12]}"
    profile = speaker_verification_service.enroll_profile(
        profile_id=pid,
        display_name=display_name,
        embedding=result.embedding,
        is_primary=is_primary,
    )

    logger.info(
        f"POST /speaker/enroll: enrolled '{display_name}' [{pid}] "
        f"dim={result.dim} ms={result.inference_ms}"
    )

    return {
        **profile.to_dict(),
        "embedding_dim": result.dim,
        "inference_ms": result.inference_ms,
        "engine": result.engine,
    }


# ── 2. Verify — Upload audio, compare against enrolled profile ────────────

@router.post("/verify")
async def verify_speaker(
    file: UploadFile = File(...),
    threshold: float = Form(default=0.75),
):
    """
    Verify a voice sample against the enrolled primary profile.

    Uploads a WAV/PCM audio file, extracts embedding, computes cosine
    similarity against the stored primary profile.

    Returns:
      { match, confidence, profile_id, display_name, similarity, inference_ms, engine }
    """
    if not speaker_verification_service.is_available:
        raise HTTPException(
            status_code=503,
            detail="Speaker verification engine not available.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    loop = asyncio.get_event_loop()
    content_type = (file.content_type or "").lower()

    if "pcm" in content_type:
        emb_result = await loop.run_in_executor(
            None, speaker_verification_service.extract_embedding_from_pcm_bytes, content, 16000
        )
    else:
        emb_result = await loop.run_in_executor(
            None, speaker_verification_service.extract_embedding_from_wav_bytes, content
        )

    if emb_result is None or not emb_result.embedding:
        raise HTTPException(
            status_code=422,
            detail="Could not extract speaker embedding from audio.",
        )

    verify_result = speaker_verification_service.verify(
        audio_embedding=emb_result.embedding,
        threshold=threshold,
    )

    logger.info(
        f"POST /speaker/verify: match={verify_result.match} "
        f"sim={verify_result.similarity:.4f} ms={emb_result.inference_ms}"
    )

    return verify_result.to_dict()


# ── 3. Extract — Upload audio, return embedding only ──────────────────────

@router.post("/extract")
async def extract_embedding(
    file: UploadFile = File(...),
):
    """
    Extract speaker embedding from audio without storing.
    Useful for diagnostics or client-side profile management.

    Returns:
      { embedding, dim, inference_ms, engine }
    """
    if not speaker_verification_service.is_available:
        raise HTTPException(
            status_code=503,
            detail="Speaker verification engine not available.",
        )

    content = await file.read()
    if not content:
        raise HTTPException(status_code=400, detail="Audio file is empty.")

    loop = asyncio.get_event_loop()
    content_type = (file.content_type or "").lower()

    if "pcm" in content_type:
        result = await loop.run_in_executor(
            None, speaker_verification_service.extract_embedding_from_pcm_bytes, content, 16000
        )
    else:
        result = await loop.run_in_executor(
            None, speaker_verification_service.extract_embedding_from_wav_bytes, content
        )

    if result is None or not result.embedding:
        raise HTTPException(
            status_code=422,
            detail="Could not extract speaker embedding from audio.",
        )

    return {
        "embedding": result.embedding,
        "dim": result.dim,
        "inference_ms": result.inference_ms,
        "engine": result.engine,
    }


# ── 4. List profiles ─────────────────────────────────────────────────────

@router.get("/profiles")
async def list_profiles():
    """
    List all enrolled speaker profiles (without embedding vectors).
    """
    profiles = speaker_verification_service.get_profiles()
    return {
        "profiles": [p.to_dict() for p in profiles],
        "count": len(profiles),
    }


# ── 5. Delete profile ─────────────────────────────────────────────────────

@router.delete("/profiles/{profile_id}")
async def delete_profile(profile_id: str):
    """Delete a speaker profile by ID."""
    deleted = speaker_verification_service.delete_profile(profile_id)
    if not deleted:
        raise HTTPException(status_code=404, detail=f"Profile '{profile_id}' not found.")
    return {"deleted": True, "profile_id": profile_id}


# ── 6. Status ─────────────────────────────────────────────────────────────

@router.get("/status")
async def speaker_status():
    """
    Returns availability and config of the speaker verification engine.
    """
    from app.core.config import settings

    return {
        "available": speaker_verification_service.is_available,
        "model": settings.SHERPA_SPEAKER_MODEL,
        "embedding_dim": speaker_verification_service.embedding_dim,
        "engine": "sherpa-onnx-ecapa512",
        "profiles_count": len(speaker_verification_service.get_profiles()),
    }
