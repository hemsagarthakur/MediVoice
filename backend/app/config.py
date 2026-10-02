from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    groq_api_key: str = Field(default="", repr=False)
    groq_model: str = "openai/gpt-oss-20b"
    demo_mode: bool = False
    app_env: str = "development"
    log_level: str = "INFO"
    api_request_timeout_seconds: float = Field(default=15.0, gt=0, le=60)
    reference_request_timeout_seconds: float = Field(default=8.0, gt=0, le=30)


@lru_cache
def get_settings() -> Settings:
    return Settings()
