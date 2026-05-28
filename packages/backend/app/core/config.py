from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "LABSYNC Enterprise API"
    version: str = "7.0.0"
    debug: bool = False

    database_url: str = "sqlite+aiosqlite:///./labsync.db"
    async_database_url: str = "sqlite+aiosqlite:///./labsync.db"
    secret_key: str = "LABSYNC_SUPER_SECRET_KEY_ENTERPRISE_7.0"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 480

    redis_url: str = "redis://localhost:6379/0"
    cors_origins: str = "*"
    sync_server_port: int = 8000

    license_github_token: str = ""
    license_repo: str = "ISTURIZrp89/biolab-licenses"

    class Config:
        env_file = ".env"


settings = Settings()
