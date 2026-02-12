import sys
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import List
import json

# Ensure parent is in path for absolute imports
_parent_dir = Path(__file__).resolve().parent.parent.parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

try:
    from medicine_backend.medicine_app.core.db import get_db
except ImportError:
    try:
        from core.db import get_db
    except ImportError:
        from backend.medicine_backend.medicine_app.core.db import get_db

try:
    from medicine_backend.medicine_app.models.medication import Medication
    from medicine_backend.medicine_app.models.schedule import MedicationSchedule
    from medicine_backend.medicine_app.schemas.medication import MedicationCreate, MedicationUpdate, Medication as MedicationSchema
    from medicine_backend.medicine_app.schemas.schedule import ScheduleCreate, ScheduleUpdate, Schedule as ScheduleSchema
except ImportError:
    from models.medication import Medication
    from models.schedule import MedicationSchedule
    from schemas.medication import MedicationCreate, MedicationUpdate, Medication as MedicationSchema
    from schemas.schedule import ScheduleCreate, ScheduleUpdate, Schedule as ScheduleSchema

router = APIRouter(prefix="/medications", tags=["Medications"])

def get_user_id(x_user_id: str = Header(...)):
    if not x_user_id:
        raise HTTPException(status_code=400, detail="X-User-Id header missing")
    return x_user_id

@router.post("/", response_model=MedicationSchema)
def create_medication(
    med: MedicationCreate, 
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    db_med = Medication(**med.model_dump(), user_id=user_id)
    db.add(db_med)
    db.commit()
    db.refresh(db_med)
    return db_med

@router.get("/", response_model=List[MedicationSchema])
def get_medications(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    return db.query(Medication).filter(
        Medication.user_id == user_id,
        Medication.is_active == True
    ).all()

@router.get("/{id}", response_model=MedicationSchema)
def get_medication(
    id: int,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    med = db.query(Medication).filter(
        Medication.id == id,
        Medication.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    return med

@router.put("/{id}", response_model=MedicationSchema)
def update_medication(
    id: int,
    med_update: MedicationUpdate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    med = db.query(Medication).filter(
        Medication.id == id,
        Medication.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    
    for key, value in med_update.model_dump(exclude_unset=True).items():
        setattr(med, key, value)
    
    db.commit()
    db.refresh(med)
    return med

@router.delete("/{id}")
def delete_medication(
    id: int,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    med = db.query(Medication).filter(
        Medication.id == id,
        Medication.user_id == user_id
    ).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
    
    med.is_active = False # Soft delete
    db.commit()
    return {"status": "success"}

# Schedule endpoints
@router.post("/{id}/schedule", response_model=ScheduleSchema)
def create_schedule(
    id: int,
    schedule: ScheduleCreate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    # Verify med belongs to user
    med = db.query(Medication).filter(Medication.id == id, Medication.user_id == user_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")
        
    # Check existing schedule? one per med
    existing = db.query(MedicationSchedule).filter(MedicationSchedule.medication_id == id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Schedule already exists")
        
    db_schedule = MedicationSchedule(
        medication_id=id,
        schedule_type=schedule.schedule_type,
        times_json=json.dumps(schedule.times),
        days_json=json.dumps(schedule.days) if schedule.days else None,
        interval_hours=schedule.interval_hours,
        timezone=schedule.timezone
    )
    db.add(db_schedule)
    db.commit()
    db.refresh(db_schedule)
    
    # Return formatted schema
    return ScheduleSchema(
        id=db_schedule.id,
        medication_id=db_schedule.medication_id,
        schedule_type=db_schedule.schedule_type,
        times=json.loads(db_schedule.times_json),
        days=json.loads(db_schedule.days_json) if db_schedule.days_json else None,
        interval_hours=db_schedule.interval_hours,
        timezone=db_schedule.timezone
    )

@router.get("/{id}/schedule", response_model=ScheduleSchema)
def get_schedule(
    id: int,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    # Verify med belongs to user
    med = db.query(Medication).filter(Medication.id == id, Medication.user_id == user_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")

    schedule = db.query(MedicationSchedule).filter(MedicationSchedule.medication_id == id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
        
    return ScheduleSchema(
        id=schedule.id,
        medication_id=schedule.medication_id,
        schedule_type=schedule.schedule_type,
        times=json.loads(schedule.times_json),
        days=json.loads(schedule.days_json) if schedule.days_json else None,
        interval_hours=schedule.interval_hours,
        timezone=schedule.timezone
    )

@router.put("/{id}/schedule", response_model=ScheduleSchema)
def update_schedule(
    id: int,
    schedule_update: ScheduleUpdate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    med = db.query(Medication).filter(Medication.id == id, Medication.user_id == user_id).first()
    if not med:
        raise HTTPException(status_code=404, detail="Medication not found")

    schedule = db.query(MedicationSchedule).filter(MedicationSchedule.medication_id == id).first()
    if not schedule:
        raise HTTPException(status_code=404, detail="Schedule not found")
        
    schedule.schedule_type = schedule_update.schedule_type
    schedule.times_json = json.dumps(schedule_update.times)
    schedule.days_json = json.dumps(schedule_update.days) if schedule_update.days else None
    schedule.interval_hours = schedule_update.interval_hours
    schedule.timezone = schedule_update.timezone
    
    db.commit()
    db.refresh(schedule)
    
    return ScheduleSchema(
        id=schedule.id,
        medication_id=schedule.medication_id,
        schedule_type=schedule.schedule_type,
        times=json.loads(schedule.times_json),
        days=json.loads(schedule.days_json) if schedule.days_json else None,
        interval_hours=schedule.interval_hours,
        timezone=schedule.timezone
    )
