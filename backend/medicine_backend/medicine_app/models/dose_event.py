import sys
from pathlib import Path
from sqlalchemy import Column, Integer, String, DateTime, Boolean, ForeignKey
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

# Use package-style import to ensure same Base instance
try:
    from medicine_backend.medicine_app.core.db import Base
except ImportError:
    from core.db import Base

class DoseEvent(Base):
    __tablename__ = "dose_events"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    medication_id = Column(Integer, ForeignKey("medications.id"), nullable=False)
    scheduled_at = Column(DateTime, nullable=False)
    status = Column(String, default="PENDING")  # PENDING, TAKEN, SKIPPED, MISSED
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    taken_at = Column(DateTime, nullable=True)
    note = Column(String, nullable=True)
