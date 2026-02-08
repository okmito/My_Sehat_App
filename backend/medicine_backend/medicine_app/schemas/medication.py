from pydantic import BaseModel
from typing import Optional
from datetime import date

class MedicationBase(BaseModel):
    name: str
    strength: Optional[str] = None
    form: Optional[str] = None
    instructions: Optional[str] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    is_active: bool = True

class MedicationCreate(MedicationBase):
    pass

class MedicationUpdate(MedicationBase):
    pass

class Medication(MedicationBase):
    id: int
    user_id: str

    class Config:
        from_attributes = True
