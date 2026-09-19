"""
speaker_verification_service.py

On-device speaker verification using sherpa-onnx ECAPA-TDNN speaker embeddings.

Adapted from:
  - sherpa-onnx/python-api-examples/speaker-verification-demo.py
  - sherpa-onnx/python-api-examples/expose-encoder-from-wespeaker.py

Architecture:
  - Uses sherpa_onnx.SpeakerEmbeddingExtractor with wespeaker-ecapa512 model
  - Accepts raw PCM audio bytes from Flutter
  - Extracts 192-dim speaker embeddings, L2-normalized
  - Cosine similarity matching against enrolled profiles
  - Profiles stored in JSON file (persistent across restarts)
"""

from __future__ import annotations

import io
import json
import time
import wave
from pathlib import Path
from typing import Optional

from app.core.config import settings
from app.core.logging import logger

try:
    import numpy as np
    import sherpa_onnx
    SHERPA_AVAILABLE = True
except ImportError:
    SHERPA_AVAILABLE = False
    np = None
    logger.warning(
        "sherpa-onnx or numpy not installed. Install with: pip install sherpa-onnx numpy"
    )


class SpeakerProfileData:
    """In-memory speaker profile with embedding vector."""

    def __init__(
        self,
        profile_id: str,
        display_name: str,
        embedding: list[float],
        is_primary: bool = True,
        model_name: str = "wespeaker-ecapa512",
        created_at: str = "",
    ):
        self.profile_id = profile_id
        self.display_name = display_name
        self.embedding = embedding
        self.is_primary = is_primary
        self.model_name = model_name
        self.created_at = created_at or time.strftime("%Y-%m-%dT%H:%M:%S")

    def to_dict(self) -> dict:
        return {
            "profile_id": self.profile_id,
            "display_name": self.display_name,
            "is_primary": self.is_primary,
            "model_name": self.model_name,
            "created_at": self.created_at,
            "embedding_dim": len(self.embedding),
        }

    def to_full_dict(self) -> dict:
        d = self.to_dict()
        d["embedding"] = self.embedding
        return d


class EmbeddingResult:
    """Result from embedding extraction."""

    def __init__(
        self,
        embedding: list[float],
        inference_ms: int = 0,
        dim: int = 0,
        engine: str = "sherpa-onnx-ecapa512",
    ):
        self.embedding = embedding
        self.inference_ms = inference_ms
        self.dim = dim or len(embedding)
        self.engine = engine

    def to_dict(self) -> dict:
        return {
            "dim": self.dim,
            "inference_ms": self.inference_ms,
            "engine": self.engine,
        }


class VerificationResult:
    """Result from speaker verification."""

    def __init__(
        self,
        match: bool,
        confidence: float,
        profile_id: str = "",
        display_name: str = "",
        similarity: float = 0.0,
        inference_ms: int = 0,
        engine: str = "sherpa-onnx-ecapa512",
    ):
        self.match = match
        self.confidence = confidence
        self.profile_id = profile_id
        self.display_name = display_name
        self.similarity = similarity
        self.inference_ms = inference_ms
        self.engine = engine

    def to_dict(self) -> dict:
        return {
            "match": self.match,
            "confidence": self.confidence,
            "profile_id": self.profile_id,
            "display_name": self.display_name,
            "similarity": self.similarity,
            "inference_ms": self.inference_ms,
            "engine": self.engine,
        }


class SpeakerVerificationService:
    """
    Singleton speaker verification service using sherpa-onnx ECAPA-TDNN.

    Loads the WeSpeaker ECAPA-TDNN model once at startup.
    Provides embedding extraction, profile enrollment, and cosine similarity verification.
    """

    _instance: Optional["SpeakerVerificationService"] = None
    _extractor: Optional[object] = None  # sherpa_onnx.SpeakerEmbeddingExtractor
    _initialized: bool = False
    _available: bool = False
    _embedding_dim: int = 0
    _profiles: dict[str, SpeakerProfileData] = {}
    _profiles_file: Optional[Path] = None

    def __new__(cls) -> "SpeakerVerificationService":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def initialize(self) -> bool:
        """
        Initialize sherpa-onnx SpeakerEmbeddingExtractor with ECAPA-TDNN model.
        Called once at FastAPI startup lifespan.
        """
        if self._initialized:
            return self._available

        if not SHERPA_AVAILABLE:
            logger.warning("SpeakerVerificationService: sherpa_onnx not available, service disabled.")
            self._initialized = True
            self._available = False
            return False

        model_path = settings.SHERPA_SPEAKER_MODEL

        if not model_path or not Path(model_path).is_file():
            logger.warning(
                f"SpeakerVerificationService: ECAPA-TDNN model not found at '{model_path}'. "
                "Set SHERPA_SPEAKER_MODEL in backend/.env"
            )
            self._initialized = True
            self._available = False
            return False

        try:
            logger.info("SpeakerVerificationService: Loading ECAPA-TDNN model...")
            t0 = time.time()

            config = sherpa_onnx.SpeakerEmbeddingExtractorConfig(
                model=model_path,
            )
            self._extractor = sherpa_onnx.SpeakerEmbeddingExtractor(config)
            self._embedding_dim = self._extractor.dim

            elapsed = (time.time() - t0) * 1000
            logger.info(
                f"SpeakerVerificationService: ✅ ECAPA-TDNN ready. "
                f"Model: {Path(model_path).name} | dim={self._embedding_dim} | Load: {elapsed:.0f}ms"
            )

            self._profiles_file = Path(settings.SPEAKER_PROFILES_FILE)
            self._load_profiles()

            self._initialized = True
            self._available = True
            return True

        except Exception as e:
            logger.error(f"SpeakerVerificationService: Failed to initialize: {e}")
            self._initialized = True
            self._available = False
            return False

    @property
    def is_available(self) -> bool:
        return self._available

    @property
    def embedding_dim(self) -> int:
        return self._embedding_dim

    # ── Embedding extraction ──────────────────────────────────────────────

    def extract_embedding_from_wav_bytes(self, wav_bytes: bytes) -> Optional[EmbeddingResult]:
        """Extract speaker embedding from WAV audio bytes."""
        samples, sample_rate = _decode_wav_bytes(wav_bytes)
        if samples is None or len(samples) == 0:
            return None
        return self._extract_embedding(samples, sample_rate)

    def extract_embedding_from_pcm_bytes(
        self, pcm_bytes: bytes, sample_rate: int = 16000
    ) -> Optional[EmbeddingResult]:
        """Extract speaker embedding from raw PCM int16 bytes."""
        if not self._available or self._extractor is None:
            return None

        try:
            pcm_int16 = np.frombuffer(pcm_bytes, dtype=np.int16)
            samples = pcm_int16.astype(np.float32) / 32768.0
            return self._extract_embedding(samples, sample_rate)
        except Exception as e:
            logger.error(f"SpeakerVerificationService: PCM extraction error: {e}")
            return None

    def _extract_embedding(
        self, samples: np.ndarray, sample_rate: int
    ) -> Optional[EmbeddingResult]:
        """Run sherpa-onnx ECAPA-TDNN inference to extract 192-dim embedding."""
        if not self._available or self._extractor is None:
            return None

        t_start = time.time()
        try:
            stream = self._extractor.create_stream()
            stream.accept_waveform(sample_rate, samples.astype(np.float32).tolist())
            stream.input_finished()

            embedding = self._extractor.compute(stream)

            elapsed_ms = int((time.time() - t_start) * 1000)

            if embedding is None or len(embedding) == 0:
                logger.warning("SpeakerVerificationService: Empty embedding from model")
                return None

            # L2 normalize
            embedding_list = embedding if isinstance(embedding, list) else embedding.tolist()
            embedding_list = _l2_normalize(embedding_list)

            logger.info(
                f"SpeakerVerificationService: Extracted embedding dim={len(embedding_list)} "
                f"({len(samples)/sample_rate:.2f}s audio, {elapsed_ms}ms)"
            )

            return EmbeddingResult(
                embedding=embedding_list,
                inference_ms=elapsed_ms,
                dim=len(embedding_list),
            )

        except Exception as e:
            elapsed_ms = int((time.time() - t_start) * 1000)
            logger.error(f"SpeakerVerificationService: Embedding extraction failed: {e}")
            return None

    # ── Profile management ────────────────────────────────────────────────

    def enroll_profile(
        self,
        profile_id: str,
        display_name: str,
        embedding: list[float],
        is_primary: bool = True,
    ) -> SpeakerProfileData:
        """Store a new speaker profile with its embedding."""
        profile = SpeakerProfileData(
            profile_id=profile_id,
            display_name=display_name,
            embedding=embedding,
            is_primary=is_primary,
        )
        self._profiles[profile_id] = profile
        self._save_profiles()
        logger.info(
            f"SpeakerVerificationService: Enrolled profile '{display_name}' "
            f"[{profile_id}] dim={len(embedding)}"
        )
        return profile

    def get_profiles(self) -> list[SpeakerProfileData]:
        """Return all enrolled profiles (without embeddings for list view)."""
        return list(self._profiles.values())

    def get_profile(self, profile_id: str) -> Optional[SpeakerProfileData]:
        """Return a specific profile with embedding."""
        return self._profiles.get(profile_id)

    def get_primary_profile(self) -> Optional[SpeakerProfileData]:
        """Return the primary enrolled profile."""
        for p in self._profiles.values():
            if p.is_primary:
                return p
        if self._profiles:
            return next(iter(self._profiles.values()))
        return None

    def delete_profile(self, profile_id: str) -> bool:
        """Delete a profile by ID."""
        if profile_id in self._profiles:
            del self._profiles[profile_id]
            self._save_profiles()
            logger.info(f"SpeakerVerificationService: Deleted profile {profile_id}")
            return True
        return False

    # ── Verification ──────────────────────────────────────────────────────

    def verify(
        self,
        audio_embedding: list[float],
        threshold: float = 0.75,
    ) -> VerificationResult:
        """
        Verify a voice sample against the enrolled primary profile.
        Returns match/no-match with cosine similarity confidence.
        """
        t_start = time.time()
        primary = self.get_primary_profile()

        if primary is None:
            elapsed_ms = int((time.time() - t_start) * 1000)
            return VerificationResult(
                match=False,
                confidence=0.0,
                similarity=0.0,
                inference_ms=elapsed_ms,
            )

        similarity = cosine_similarity(audio_embedding, primary.embedding)
        is_match = similarity >= threshold
        elapsed_ms = int((time.time() - t_start) * 1000)

        logger.info(
            f"SpeakerVerificationService: Verify vs '{primary.display_name}' "
            f"→ sim={similarity:.4f} match={is_match} ({elapsed_ms}ms)"
        )

        return VerificationResult(
            match=is_match,
            confidence=similarity,
            profile_id=primary.profile_id,
            display_name=primary.display_name,
            similarity=similarity,
            inference_ms=elapsed_ms,
        )

    # ── Persistence ───────────────────────────────────────────────────────

    def _load_profiles(self):
        """Load profiles from JSON file."""
        if self._profiles_file is None:
            return
        try:
            if self._profiles_file.exists():
                data = json.loads(self._profiles_file.read_text(encoding="utf-8"))
                for item in data:
                    profile = SpeakerProfileData(
                        profile_id=item["profile_id"],
                        display_name=item["display_name"],
                        embedding=item["embedding"],
                        is_primary=item.get("is_primary", True),
                        model_name=item.get("model_name", "wespeaker-ecapa512"),
                        created_at=item.get("created_at", ""),
                    )
                    self._profiles[profile.profile_id] = profile
                logger.info(
                    f"SpeakerVerificationService: Loaded {len(self._profiles)} profiles from disk"
                )
        except Exception as e:
            logger.error(f"SpeakerVerificationService: Failed to load profiles: {e}")

    def _save_profiles(self):
        """Save profiles to JSON file."""
        if self._profiles_file is None:
            return
        try:
            self._profiles_file.parent.mkdir(parents=True, exist_ok=True)
            data = [p.to_full_dict() for p in self._profiles.values()]
            self._profiles_file.write_text(
                json.dumps(data, indent=2), encoding="utf-8"
            )
        except Exception as e:
            logger.error(f"SpeakerVerificationService: Failed to save profiles: {e}")


# ── Module-level helpers ───────────────────────────────────────────────────

def _l2_normalize(embedding: list[float]) -> list[float]:
    """L2-normalize a vector."""
    norm = sum(x * x for x in embedding)
    norm = norm ** 0.5 if norm > 0 else 1.0
    return [x / norm for x in embedding]


def cosine_similarity(a: list[float], b: list[float]) -> float:
    """Compute cosine similarity between two vectors."""
    if not a or not b:
        return 0.0
    min_len = min(len(a), len(b))
    dot = sum(a[i] * b[i] for i in range(min_len))
    norm_a = sum(x * x for x in a[:min_len]) ** 0.5
    norm_b = sum(x * x for x in b[:min_len]) ** 0.5
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return max(-1.0, min(1.0, dot / (norm_a * norm_b)))


def _decode_wav_bytes(wav_bytes: bytes) -> tuple[Optional[np.ndarray], int]:
    """Decode WAV bytes to float32 mono numpy array at original sample rate."""
    try:
        with wave.open(io.BytesIO(wav_bytes)) as wf:
            n_channels = wf.getnchannels()
            sample_width = wf.getsampwidth()
            sample_rate = wf.getframerate()
            n_frames = wf.getnframes()
            raw_bytes = wf.readframes(n_frames)

        if sample_width == 2:
            dtype = np.int16
            divisor = 32768.0
        elif sample_width == 4:
            dtype = np.int32
            divisor = 2147483648.0
        elif sample_width == 1:
            dtype = np.uint8
            divisor = 128.0
        else:
            logger.error(f"SpeakerVerificationService: Unsupported sample width: {sample_width}")
            return None, 0

        samples = np.frombuffer(raw_bytes, dtype=dtype).astype(np.float32) / divisor

        # Downmix to mono
        if n_channels > 1:
            samples = samples.reshape(-1, n_channels).mean(axis=1)

        return samples, sample_rate

    except Exception as e:
        logger.error(f"SpeakerVerificationService: WAV decode error: {e}")
        return None, 0


# ── Module-level singleton ─────────────────────────────────────────────────
speaker_verification_service = SpeakerVerificationService()
