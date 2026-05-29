import logging
import secrets

from pydantic import field_validator
from pydantic_settings import BaseSettings

logger = logging.getLogger(__name__)

DEFAULT_SECRET_PLACEHOLDERS = {
    "change-me-in-production-use-a-strong-random-key",
    "change-in-production",
    "changeme",
    "",
}


class Settings(BaseSettings):
    app_name: str = "LABSYNC Enterprise API"
    version: str = "0.0.0.1"
    debug: bool = False

    database_url: str = "sqlite+aiosqlite:///./labsync.db"
    async_database_url: str = "sqlite+aiosqlite:///./labsync.db"
    secret_key: str = ""
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 480

    redis_url: str = "redis://localhost:6379/0"
    cors_origins: str = "http://localhost:8000,http://127.0.0.1:8000"
    sync_server_port: int = 8000

    license_github_token: str = ""
    license_repo: str = "ISTURIZrp89/biolab-licenses"

    @field_validator("secret_key")
    @classmethod
    def validate_secret_key(cls, v: str) -> str:
        if not v or v in DEFAULT_SECRET_PLACEHOLDERS:
            if v in DEFAULT_SECRET_PLACEHOLDERS:
                logger.warning(
                    "SECRET_KEY is using a default/insecure value. "
                    "Generating a random key for this session. "
                    "Set a strong SECRET_KEY in .env for production."
                )
                v = secrets.token_hex(32)
            else:
                logger.warning(
                    "SECRET_KEY is empty. Generating a random key for this session. "
                    "Set a strong SECRET_KEY in .env for production."
                )
                v = secrets.token_hex(32)
        if len(v) < 32:
            logger.warning(
                "SECRET_KEY is too short (%d chars). Minimum recommended: 32 chars.",
                len(v),
            )
        return v

    class Config:
        env_file = ".env"


settings = Settings()
