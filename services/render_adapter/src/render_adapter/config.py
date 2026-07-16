from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    HERMES_URL: str = "https://api.deepseek.com"
    HERMES_API_KEY: str = "sk-42bd9fa4640e4f588bfcd7a08d150777"
    HERMES_MODEL: str = "deepseek-v4-pro"
    HOST: str = "0.0.0.0"
    PORT: int = 8700
    HITL_TIMEOUT_SECONDS: int = 300
    LOG_LEVEL: str = "info"

    model_config = SettingsConfigDict(env_prefix="ADAPTER_", env_file=".env", extra="ignore")

_settings = None

def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
