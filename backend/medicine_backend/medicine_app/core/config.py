import os
from pathlib import Path

class Settings:
    PROJECT_NAME: str = "Medicine & Reminder Backend"
    TIMEZONE: str = "Asia/Kolkata"
    
    def __init__(self):
        # Detect Render environment
        render_env = os.environ.get("RENDER", None)
        if render_env or os.environ.get("PORT"):
            # On Render, use /tmp for writable storage
            db_file = Path("/tmp/medicine.db")
            upload_dir = Path("/tmp/uploads")
        else:
            # Local development: use backend directory
            backend_dir = Path(__file__).resolve().parent.parent.parent
            db_file = backend_dir / "medicine.db"
            upload_dir = backend_dir / "uploads"
        self.DATABASE_URL = f"sqlite:///{db_file}"
        self.UPLOAD_DIR = str(upload_dir)
        # Ensure upload directory exists
        os.makedirs(self.UPLOAD_DIR, exist_ok=True)

settings = Settings()
