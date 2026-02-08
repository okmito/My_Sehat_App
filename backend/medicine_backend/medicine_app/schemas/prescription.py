from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime

class PrescriptionBase(BaseModel):
    extraction_status: str

class PrescriptionCreate(BaseModel):
    pass

class PrescriptionConfirm(BaseModel):
    medications: List[Dict[str, Any]]

class Prescription(PrescriptionBase):
    id: int
    user_id: str
    file_path: str
    uploaded_at: datetime
    extracted_json: Optional[str] = None

    class Config:
        from_attributes = True
