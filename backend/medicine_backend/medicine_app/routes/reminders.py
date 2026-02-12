import sys
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Header, Query
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime

# Ensure parent is in path for absolute imports
_parent_dir = Path(__file__).resolve().parent.parent.parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

from medicine_backend.medicine_app.core.db import get_db
from medicine_backend.medicine_app.models.dose_event import DoseEvent
from medicine_backend.medicine_app.models.medication import Medication
from medicine_backend.medicine_app.services.reminder_service import generate_dose_events, process_missed_doses
from medicine_backend.medicine_app.schemas.dose_event import DoseEvent as DoseEventSchema, DoseEventUpdate

router = APIRouter(tags=["Reminders"])

def get_user_id(x_user_id: str = Header(...)):
    if not x_user_id:
        raise HTTPException(status_code=400, detail="X-User-Id header missing")
    return x_user_id

@router.post("/reminders/generate")
def generate_reminders(
    days: int = 7,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    count = generate_dose_events(db, user_id, days)
    return {"status": "success", "generated_count": count}

@router.get("/reminders/today", response_model=List[DoseEventSchema])
def get_todays_reminders(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    # Auto-process missed events first
    process_missed_doses(db, user_id)
    
    # Filter for today
    # Assuming "today" means local time date match
    # Or just return pending/today events?
    # Simple approach: Return all pending or recent?
    # Requirement: "GET /reminders/today"
    
    # Let's get "Start of today" to "End of today" in user timezone?
    # Simpler: just get events where scheduled_at.date() == today
    from medicine_backend.medicine_app.services.reminder_service import get_current_time
    now = get_current_time()
    today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    today_end = now.replace(hour=23, minute=59, second=59, microsecond=999)
    
    reminders = db.query(DoseEvent).join(Medication).filter(
        Medication.user_id == user_id,
        DoseEvent.scheduled_at >= today_start,
        DoseEvent.scheduled_at <= today_end
    ).order_by(DoseEvent.scheduled_at).all()
    
    # Enrich with medication name and strength
    result = []
    for reminder in reminders:
        med = db.query(Medication).filter(Medication.id == reminder.medication_id).first()
        result.append({
            "id": reminder.id,
            "medication_id": reminder.medication_id,
            "medication_name": med.name if med else "Unknown",
            "strength": med.strength if med else None,
            "scheduled_at": reminder.scheduled_at,
            "updated_at": reminder.updated_at,
            "taken_at": reminder.taken_at,
            "status": reminder.status,
            "note": reminder.note,
        })
    
    return result

@router.get("/reminders/next", response_model=List[DoseEventSchema])
def get_next_reminders(
    limit: int = 10,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    process_missed_doses(db, user_id)
    
    from medicine_backend.medicine_app.services.reminder_service import get_current_time
    now = get_current_time()
    
    # Get future pending reminders
    reminders = db.query(DoseEvent).join(Medication).filter(
        Medication.user_id == user_id,
        DoseEvent.scheduled_at >= now,
        DoseEvent.status == "PENDING"
    ).order_by(DoseEvent.scheduled_at).limit(limit).all()
    
    return reminders

@router.post("/dose-events/{id}/mark", response_model=DoseEventSchema)
def mark_dose_event(
    id: int,
    status_update: DoseEventUpdate,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    # Join medication to ensure ownership
    event = db.query(DoseEvent).join(Medication).filter(
        DoseEvent.id == id,
        Medication.user_id == user_id
    ).first()
    
    if not event:
        raise HTTPException(status_code=404, detail="Dose event not found")
        
    event.status = status_update.status
    event.note = status_update.note
    
    from datetime import datetime
    if status_update.status == "TAKEN":
        event.taken_at = datetime.utcnow()
        
    db.commit()
    db.refresh(event)
    return event
