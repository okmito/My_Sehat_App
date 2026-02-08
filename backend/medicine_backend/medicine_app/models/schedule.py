import sys
from pathlib import Path
from sqlalchemy import Column, Integer, String, ForeignKey

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

# Use package-style import to ensure same Base instance
try:
    from medicine_backend.medicine_app.core.db import Base
except ImportError:
    from core.db import Base

class MedicationSchedule(Base):
    __tablename__ = "medication_schedules"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    medication_id = Column(Integer, ForeignKey("medications.id"), nullable=False)
    schedule_type = Column(String, nullable=False)  # DAILY, WEEKLY, INTERVAL
    times_json = Column(String, nullable=False)  # JSON list ["08:00", "20:00"]
    days_json = Column(String, nullable=True)  # JSON list [1, 3, 5] (Mon, Wed, Fri)
    interval_hours = Column(Integer, nullable=True)
    timezone = Column(String, default="Asia/Kolkata")
