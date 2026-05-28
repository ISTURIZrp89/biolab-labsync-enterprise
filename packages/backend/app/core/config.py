from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    app_name: str = "BioLab LABSYNC Enterprise"
    version: str = "7.0.0"
    debug: bool = False

    database_url: str = "postgresql+asyncpg://biolab:biolab_pass@localhost:5432/biolab"
    secret_key: str = "change-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 480

    redis_url: str = "redis://localhost:6379/0"

    license_github_token: str = ""
    license_repo: str = "ISTURIZrp89/biolab-licenses"

    class Config:
        env_file = ".env"


settings = Settings()
