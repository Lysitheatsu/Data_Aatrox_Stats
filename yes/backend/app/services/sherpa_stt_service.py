"""
sherpa_stt_service.py

On-device Sherpa-ONNX SenseVoice CTC speech recognition service for
the Elly SOS Python backend.

Adapted from:
  - sherpa-onnx/python-api-examples/offline-sense-voice-ctc-decode-files.py
  - sherpa-onnx/python-api-examples/vad-with-non-streaming-asr.py
  - sherpa-onnx/python-api-examples/simulate-streaming-sense-voice-microphone.py

Architecture:
  - Uses sherpa_onnx.OfflineRecognizer.from_sense_voice()
  - Uses sherpa_onnx.VoiceActivityDetector with Silero VAD to segment speech
  - Accepts raw WAV/PCM audio bytes from Flutter mobile app
  - Returns transcribed text, emotion tags, and language
"""

from __future__ import annotations

import io
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
        "sherpa-onnx or numpy not installed. Install with: pip install sherpa-onnx numpy soundfile\n"
        "Falling back to Groq Whisper for STT."
    )


class SherpaSttResult:
    """Structured result from Sherpa-ONNX SenseVoice recognition."""

    def __init__(
        self,
        text: str,
        language: str = "en",
        emotion: str = "",
        confidence: float = 0.92,
        inference_ms: int = 0,
        engine: str = "sherpa-onnx-sense-voice",
    ):
        self.text = text
        self.language = language
        self.emotion = emotion
        self.confidence = confidence
        self.inference_ms = inference_ms
        self.engine = engine

    def to_dict(self) -> dict:
        return {
            "text": self.text,
            "language": self.language,
            "emotion": self.emotion,
            "confidence": self.confidence,
            "inference_ms": self.inference_ms,
            "engine": self.engine,
        }


class SherpaSttService:
    """
    Singleton Sherpa-ONNX SenseVoice CTC recognition service.

    Loads the SenseVoice int8 ONNX model and Silero VAD once at startup.
    All subsequent calls reuse the loaded models (zero cold-start latency).

    Model paths are configured in backend/.env:
      SHERPA_SENSE_VOICE_MODEL=/path/to/model.int8.onnx
      SHERPA_SENSE_VOICE_TOKENS=/path/to/tokens.txt
      SHERPA_SILERO_VAD_MODEL=/path/to/silero_vad.onnx
    """

    _instance: Optional["SherpaSttService"] = None
    _recognizer: Optional[object] = None  # sherpa_onnx.OfflineRecognizer
    _vad_config: Optional[object] = None  # sherpa_onnx.VadModelConfig
    _initialized: bool = False
    _available: bool = False

    def __new__(cls) -> "SherpaSttService":
        if cls._instance is None:
            cls._instance = super().__new__(cls)
        return cls._instance

    def initialize(self) -> bool:
        """
        Initialize Sherpa-ONNX SenseVoice recognizer and Silero VAD.
        Called once at FastAPI startup lifespan.
        Returns True if initialization succeeded.
        """
        if self._initialized:
            return self._available

        if not SHERPA_AVAILABLE:
            logger.warning("SherpaSttService: sherpa_onnx not available, service disabled.")
            self._initialized = True
            self._available = False
            return False

        model_path = settings.SHERPA_SENSE_VOICE_MODEL
        tokens_path = settings.SHERPA_SENSE_VOICE_TOKENS
        vad_model_path = settings.SHERPA_SILERO_VAD_MODEL

        # Validate model files exist
        if not model_path or not Path(model_path).is_file():
            logger.warning(
                f"SherpaSttService: SenseVoice model not found at '{model_path}'. "
                "Set SHERPA_SENSE_VOICE_MODEL in backend/.env"
            )
            self._initialized = True
            self._available = False
            return False

        if not tokens_path or not Path(tokens_path).is_file():
            logger.warning(
                f"SherpaSttService: SenseVoice tokens not found at '{tokens_path}'. "
                "Set SHERPA_SENSE_VOICE_TOKENS in backend/.env"
            )
            self._initialized = True
            self._available = False
            return False

        try:
            logger.info("SherpaSttService: Loading SenseVoice CTC model...")
            t0 = time.time()

            # ── Create OfflineRecognizer with SenseVoice CTC ─────────────────
            # Pattern from: offline-sense-voice-ctc-decode-files.py
            self._recognizer = sherpa_onnx.OfflineRecognizer.from_sense_voice(
                model=model_path,
                tokens=tokens_path,
                num_threads=2,
                use_itn=True,   # Inverse Text Normalization (converts "one two three" -> "123")
                debug=False,
            )

            # ── Create Silero VAD config ──────────────────────────────────────
            # Pattern from: vad-with-non-streaming-asr.py and
            #               simulate-streaming-sense-voice-microphone.py
            if vad_model_path and Path(vad_model_path).is_file():
                self._vad_config = sherpa_onnx.VadModelConfig()
                self._vad_config.silero_vad.model = vad_model_path
                self._vad_config.silero_vad.threshold = 0.5
                self._vad_config.silero_vad.min_silence_duration = 0.25   # seconds
                self._vad_config.silero_vad.min_speech_duration = 0.1     # seconds
                self._vad_config.silero_vad.max_speech_duration = 30.0    # seconds
                self._vad_config.sample_rate = 16000
                logger.info("SherpaSttService: Silero VAD loaded.")
            else:
                logger.warning(
                    f"SherpaSttService: Silero VAD model not found at '{vad_model_path}'. "
                    "VAD-assisted segmentation disabled. Set SHERPA_SILERO_VAD_MODEL in .env"
                )
                self._vad_config = None

            elapsed = (time.time() - t0) * 1000
            logger.info(
                f"SherpaSttService: ✅ SenseVoice CTC ready. "
                f"Model: {Path(model_path).name} | Load time: {elapsed:.0f}ms"
            )
            self._initialized = True
            self._available = True
            return True

        except Exception as e:
            logger.error(f"SherpaSttService: Failed to initialize: {e}")
            self._initialized = True
            self._available = False
            return False

    @property
    def is_available(self) -> bool:
        return self._available

    def transcribe_wav_bytes(self, wav_bytes: bytes) -> SherpaSttResult:
        """
        Transcribe raw WAV audio bytes using Sherpa-ONNX SenseVoice CTC.

        The audio is decoded into 16kHz mono float32 PCM samples.
        If Silero VAD is available, it segments speech before recognition.
        Otherwise, the full audio is passed directly to SenseVoice.

        Args:
            wav_bytes: Raw WAV file bytes (any sample rate, mono/stereo).

        Returns:
            SherpaSttResult with transcribed text, emotion, language, confidence.

        Pattern adapted from:
          - offline-sense-voice-ctc-decode-files.py (stream.accept_waveform + decode_stream)
          - vad-with-non-streaming-asr.py (VAD segmentation loop)
        """
        if not self._available or self._recognizer is None:
            return SherpaSttResult(text="", confidence=0.0, engine="sherpa-onnx-unavailable")

        t_start = time.time()

        try:
            # ── 1. Decode WAV bytes to float32 samples ──────────────────────
            samples, sample_rate = _decode_wav_bytes(wav_bytes)

            if samples is None or len(samples) == 0:
                logger.warning("SherpaSttService: Empty or invalid audio data.")
                return SherpaSttResult(text="", confidence=0.0)

            logger.info(
                f"SherpaSttService: Transcribing {len(samples)/sample_rate:.2f}s "
                f"audio at {sample_rate}Hz ({len(samples)} samples)..."
            )

            # ── 2. VAD-assisted segmentation (if Silero VAD available) ───────
            if self._vad_config is not None:
                text = self._transcribe_with_vad(samples, sample_rate)
            else:
                text = self._transcribe_direct(samples, sample_rate)

            elapsed_ms = int((time.time() - t_start) * 1000)
            text = text.strip()

            if text:
                logger.info(
                    f"SherpaSttService: ✅ Transcript -> \"{text}\" "
                    f"({elapsed_ms}ms)"
                )
            else:
                logger.info(f"SherpaSttService: No speech detected ({elapsed_ms}ms).")

            return SherpaSttResult(
                text=text,
                confidence=0.92 if text else 0.0,
                inference_ms=elapsed_ms,
            )

        except Exception as e:
            elapsed_ms = int((time.time() - t_start) * 1000)
            logger.error(f"SherpaSttService: Transcription error: {e}")
            return SherpaSttResult(text="", confidence=0.0, inference_ms=elapsed_ms)

    def transcribe_pcm_bytes(
        self, pcm_bytes: bytes, sample_rate: int = 16000
    ) -> SherpaSttResult:
        """
        Transcribe raw PCM int16 bytes (no WAV header).

        Used when Flutter sends raw PCM frames directly without WAV wrapping.

        Args:
            pcm_bytes: Raw PCM int16 little-endian bytes.
            sample_rate: Sample rate of the PCM audio (default 16000).

        Returns:
            SherpaSttResult with transcribed text.
        """
        if not self._available or self._recognizer is None:
            return SherpaSttResult(text="", confidence=0.0, engine="sherpa-onnx-unavailable")

        try:
            # Convert raw int16 PCM bytes -> float32 samples [-1.0, 1.0]
            pcm_int16 = np.frombuffer(pcm_bytes, dtype=np.int16)
            samples = pcm_int16.astype(np.float32) / 32768.0

            if self._vad_config is not None:
                text = self._transcribe_with_vad(samples, sample_rate)
            else:
                text = self._transcribe_direct(samples, sample_rate)

            return SherpaSttResult(
                text=text.strip(),
                confidence=0.92 if text.strip() else 0.0,
            )
        except Exception as e:
            logger.error(f"SherpaSttService: PCM transcription error: {e}")
            return SherpaSttResult(text="", confidence=0.0)

    def _transcribe_direct(self, samples: np.ndarray, sample_rate: int) -> str:
        """
        Direct transcription of audio samples without VAD segmentation.

        Pattern from: offline-sense-voice-ctc-decode-files.py
          stream = recognizer.create_stream()
          stream.accept_waveform(sample_rate, audio)
          recognizer.decode_stream(stream)
          text = stream.result.text
        """
        stream = self._recognizer.create_stream()
        stream.accept_waveform(sample_rate, samples)
        self._recognizer.decode_stream(stream)
        return stream.result.text

    def _transcribe_with_vad(self, samples: np.ndarray, sample_rate: int) -> str:
        """
        VAD-segmented transcription using Silero VAD + SenseVoice CTC.

        Pattern from: vad-with-non-streaming-asr.py
          config = sherpa_onnx.VadModelConfig()
          vad = sherpa_onnx.VoiceActivityDetector(config, buffer_size_in_seconds=100)
          vad.accept_waveform(buffer[:window_size])
          while not vad.empty():
              stream = recognizer.create_stream()
              stream.accept_waveform(sample_rate, vad.front.samples)
              vad.pop()
              recognizer.decode_stream(stream)
              text = stream.result.text
        """
        vad = sherpa_onnx.VoiceActivityDetector(
            self._vad_config, buffer_size_in_seconds=100
        )
        window_size = self._vad_config.silero_vad.window_size

        # Feed all samples through VAD in window_size chunks
        offset = 0
        while offset + window_size <= len(samples):
            vad.accept_waveform(samples[offset : offset + window_size])
            offset += window_size

        # Flush remaining samples
        if offset < len(samples):
            # Pad to window_size with zeros
            remaining = samples[offset:]
            padded = np.zeros(window_size, dtype=np.float32)
            padded[: len(remaining)] = remaining
            vad.accept_waveform(padded)

        # Signal end of input
        vad.flush()

        # Collect all transcribed segments
        texts: list[str] = []
        while not vad.empty():
            speech_segment = vad.front.samples
            vad.pop()

            if len(speech_segment) == 0:
                continue

            stream = self._recognizer.create_stream()
            stream.accept_waveform(sample_rate, speech_segment)
            self._recognizer.decode_stream(stream)

            segment_text = stream.result.text.strip()
            if segment_text:
                texts.append(segment_text)
                logger.info(f"SherpaSttService: VAD segment -> \"{segment_text}\"")

        # If VAD found no segments, fall back to direct decode of whole audio
        if not texts:
            logger.info("SherpaSttService: VAD found no speech segments. Falling back to direct decode.")
            return self._transcribe_direct(samples, sample_rate)

        return " ".join(texts)


# ── Module-level helpers ─────────────────────────────────────────────────────

def _decode_wav_bytes(wav_bytes: bytes) -> tuple[Optional[np.ndarray], int]:
    """
    Decode WAV bytes to float32 mono numpy array at original sample rate.
    Handles mono and stereo WAV files.
    Returns (samples, sample_rate) or (None, 0) on error.
    """
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
            logger.error(f"SherpaSttService: Unsupported sample width: {sample_width}")
            return None, 0

        samples = np.frombuffer(raw_bytes, dtype=dtype).astype(np.float32) / divisor

        # Downmix to mono if stereo
        if n_channels > 1:
            samples = samples.reshape(-1, n_channels)
            samples = samples.mean(axis=1)

        return samples, sample_rate

    except Exception as e:
        logger.error(f"SherpaSttService: WAV decode error: {e}")
        return None, 0


# ── Module-level singleton ───────────────────────────────────────────────────
sherpa_stt_service = SherpaSttService()
