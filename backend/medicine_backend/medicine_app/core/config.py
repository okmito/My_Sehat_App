import os
from pathlib import Path

class Settings:
    PROJECT_NAME: str = "Medicine & Reminder Backend"
    TIMEZONE: str = "Asia/Kolkata"
    
    def __init__(self):
        # Use absolute path for database to work from any working directory
        backend_dir = Path(__file__).resolve().parent.parent.parent
        db_file = backend_dir / "medicine.db"
        self.DATABASE_URL = f"sqlite:///{db_file}"
        
        # Upload directory: use absolute path
        upload_dir = backend_dir / "uploads"
        self.UPLOAD_DIR = str(upload_dir)
        
        # Ensure upload directory exists
        os.makedirs(self.UPLOAD_DIR, exist_ok=True)

settings = Settings()
