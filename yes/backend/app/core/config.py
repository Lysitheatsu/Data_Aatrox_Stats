"""Application configuration, loaded from environment / `.env`."""

from __future__ import annotations

from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """Runtime settings for the ELLY Maps backend.

    Values are read from environment variables (or a local `.env` file). See
    `.env.example` for the full list.
    """

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    app_name: str = "ELLY Maps API"
    environment: str = "development"

    # Comma-separated in the environment; split into a list below.
    cors_origins: str = "http://localhost:3000,http://localhost:8081"
    # Development frontends may be opened through localhost, a LAN address,
    # or Tailscale. Restrict the wildcard host to the known dev-server ports.
    cors_origin_regex: str = r"^https?://[^/]+:(?:8081|5173)$"

    # External providers — left blank in the boilerplate.
    google_maps_api_key: str = ""
    mapbox_token: str = ""
    database_url: str = ""
    redis_url: str = ""
    anthropic_api_key: str = ""

    # SOS Backend
    PROJECT_NAME: str = "Elly SOS Backend"
    VERSION: str = "2.0.0"
    API_V1_STR: str = "/v1"

    # Security & Auth
    SECRET_KEY: str = "elly_sos_super_secret_jwt_key_32_bytes_min_prod"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7
    ALGORITHM: str = "HS256"

    # CORS & Networks
    ALLOWED_ORIGINS: List[str] = ["*"]

    # Database & Redis
    DATABASE_URL: str = "sqlite+aiosqlite:///./elly_sos.db"
    REDIS_URL: str = "redis://localhost:6379/0"

    # Emergency Configurations
    DEFAULT_EMERGENCY_NUMBER: str = "112"
    DEFAULT_COUNTRY_CODE: str = "IN"

    # Cloud AI & STT Integrations
    GROQ_API_KEY: str = ""

    # Sherpa-ONNX SenseVoice CTC
    SHERPA_SENSE_VOICE_MODEL: str = ""
    SHERPA_SENSE_VOICE_TOKENS: str = ""

    # Silero VAD
    SHERPA_SILERO_VAD_MODEL: str = ""

    # Number of threads for Sherpa-ONNX inference.
    SHERPA_NUM_THREADS: int = 2

    # Sherpa-ONNX ECAPA-TDNN Speaker Embedding
    SHERPA_SPEAKER_MODEL: str = ""
    SPEAKER_PROFILES_FILE: str = "./data/speaker_profiles.json"

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def cors_origin_pattern(self) -> str | None:
        if self.environment.lower() == "production":
            return None
        return self.cors_origin_regex or None


@lru_cache
def get_settings() -> Settings:
    """Return a cached Settings instance."""
    return Settings()


settings = get_settings()
