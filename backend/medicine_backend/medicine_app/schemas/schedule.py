from pydantic import BaseModel
from typing import List, Optional

class ScheduleBase(BaseModel):
    schedule_type: str  # DAILY, WEEKLY, INTERVAL
    times: List[str]  # e.g., ["08:00", "20:00"]
    days: Optional[List[int]] = None  # e.g., [1, 3, 5]
    interval_hours: Optional[int] = None
    timezone: str = "Asia/Kolkata"

class ScheduleCreate(ScheduleBase):
    pass

class ScheduleUpdate(ScheduleBase):
    pass

class Schedule(ScheduleBase):
    id: int
    medication_id: int

    class Config:
        from_attributes = True
