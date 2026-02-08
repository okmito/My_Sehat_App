import os
from pathlib import Path
from pydantic_settings import BaseSettings
from typing import Optional

class Settings(BaseSettings):
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Triage Backend"
    
    # Environment variables
    APP_ENV: str = "development"
    
    # Database: Use absolute path to ensure it works from any working directory
    _db_path: Optional[str] = None
    
    @property
    def DATABASE_URL(self) -> str:
        if self._db_path:
            return self._db_path
        # Default: Create DB in backend folder, not current working directory
        backend_dir = Path(__file__).resolve().parent.parent.parent
        db_file = backend_dir / "sql_app.db"
        return f"sqlite:///{db_file}"
    
    OBJECT_STORAGE_BUCKET: Optional[str] = None
    VISION_MODEL_API_KEY: Optional[str] = None
    LLM_API_KEY: Optional[str] = None
    TRANSLATION_API_KEY: Optional[str] = None
    GROQ_API_KEY: Optional[str] = None  # Allow GROQ API key from .env

    class Config:
        env_file = ".env"
        case_sensitive = True
        extra = "ignore"  # Ignore extra fields from environment

settings = Settings()
