"""
Configuration settings for Health Record Backend
"""
import os
from pathlib import Path
from pydantic_settings import BaseSettings

# Load .env from parent directory
from dotenv import load_dotenv
parent_env = Path(__file__).resolve().parent.parent.parent / ".env"
if parent_env.exists():
    load_dotenv(parent_env)

class Settings(BaseSettings):
    PROJECT_NAME: str = "MySehat Health Record Service"
    API_V1_STR: str = "/api/v1"
    APP_ENV: str = os.getenv("APP_ENV", "development")
    
    # Database
    DATABASE_URL: str = os.getenv("DATABASE_URL", "sqlite:///./health_records.db")
    
    # GROQ API for document analysis
    GROQ_API_KEY: str = os.getenv("GROQ_API_KEY", "")
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    
    # Encryption settings for DPDP compliance
    ENCRYPTION_KEY: str = os.getenv("HEALTH_RECORD_ENCRYPTION_KEY", "default-dev-key-change-in-prod")
    
    # Storage settings
    UPLOAD_DIR: str = "./health_record_uploads"
    MAX_FILE_SIZE_MB: int = 10
    ALLOWED_EXTENSIONS: list = [".jpg", ".jpeg", ".png", ".pdf"]
    
    # Auto-delete settings for temporary storage
    TEMP_STORAGE_DAYS: int = 30
    
    class Config:
        case_sensitive = True

settings = Settings()
