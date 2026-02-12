from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class DoseEventBase(BaseModel):
    status: str
    note: Optional[str] = None

class DoseEventUpdate(BaseModel):
    status: str
    note: Optional[str] = None

class DoseEvent(DoseEventBase):
    id: int
    medication_id: int
    medication_name: Optional[str] = None  # Added for display purposes
    strength: Optional[str] = None  # Added for display purposes
    scheduled_at: datetime
    updated_at: Optional[datetime] = None
    taken_at: Optional[datetime] = None

    class Config:
        from_attributes = True
