import sys
from pathlib import Path
from sqlalchemy import Column, Integer, String, Boolean, Date

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.db import Base

class Medication(Base):
    __tablename__ = "medications"
    __table_args__ = {'extend_existing': True}

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)  # From X-User-Id
    name = Column(String, nullable=False)
    strength = Column(String, nullable=True)
    form = Column(String, nullable=True)  # tablet, syrup, etc.
    instructions = Column(String, nullable=True)
    start_date = Column(Date, nullable=True)
    end_date = Column(Date, nullable=True)
    is_active = Column(Boolean, default=True)
