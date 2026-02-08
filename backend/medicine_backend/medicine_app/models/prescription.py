import sys
from pathlib import Path
from sqlalchemy import Column, Integer, String, DateTime
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

# Use package-style import to ensure same Base instance
try:
    from medicine_backend.medicine_app.core.db import Base
except ImportError:
    from core.db import Base

class Prescription(Base):
    __tablename__ = "prescriptions"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)
    file_path = Column(String, nullable=False)
    uploaded_at = Column(DateTime, default=datetime.utcnow)
    extraction_status = Column(String, default="UPLOADED")  # UPLOADED, CONFIRMED
    extracted_json = Column(String, nullable=True)  # Store JSON as string if needed, or structured data
