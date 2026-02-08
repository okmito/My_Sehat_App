import json
from datetime import datetime, timedelta
import pytz
from sqlalchemy.orm import Session
from medicine_backend.medicine_app.models.medication import Medication
from medicine_backend.medicine_app.models.schedule import MedicationSchedule
from medicine_backend.medicine_app.models.dose_event import DoseEvent
from medicine_backend.medicine_app.core.config import settings

def get_current_time():
    tz = pytz.timezone(settings.TIMEZONE)
    return datetime.now(tz).replace(tzinfo=None) # naive datetime but in correct local time for simple comparison if needed, OR keep aware. 
    # For SQLite simplicity with default datetime, we often use naive UTC or naive local. 
    # Requirement says "Fixed to Asia/Kolkata". 
    # Let's stick to simple naive datetimes representing Kolkata time to avoid SQLite complexity, 
    # or consistently use UTC. Given "local file db" and "beginner friendly", naive local time is often easiest to debug.
    # However, best practice is UTC. Let's try to stick to generic datetime objects but handle timezone logic explicitly.
    # actually, `datetime.utcnow()` was used in models. Let's stick to that for storage, but convert for "Today" logic?
    # Wait, requirement says "Timezone: Fixed to Asia/Kolkata".
    # Let's use Kolkata time for everything to match the user's mental model directly.
    return datetime.now(pytz.timezone(settings.TIMEZONE)).replace(tzinfo=None)

def generate_dose_events(db: Session, user_id: str, days: int = 7):
    """
    Generates dose events for all active medications of the user for the next N days.
    """
    # Get all active medications for user
    meds = db.query(Medication).filter(
        Medication.user_id == user_id, 
        Medication.is_active == True
    ).all()
    
    start_time = get_current_time()
    end_time = start_time + timedelta(days=days)

    generated_count = 0

    for med in meds:
        # Find schedule
        schedule = db.query(MedicationSchedule).filter(
            MedicationSchedule.medication_id == med.id
        ).first()

        if not schedule:
            continue
        
        # Parse schedule
        try:
            times = json.loads(schedule.times_json)
        except:
            continue
            
        days_of_week = []
        if schedule.days_json:
            try:
                days_of_week = json.loads(schedule.days_json)
            except:
                pass

        # Iterate through days
        current_day = start_time.date()
        end_day = end_time.date()
        
        while current_day <= end_day:
            # Check if this day is allowed
            # Weekday: 0=Mon, 6=Sun. 
            # If days_of_week is specified (e.g. [1,3,5]), check matches.
            # If schedule_type is DAILY, we assume all days unless days_of_week restricts it.
            # If WEEKLY, days_of_week is mandatory usually.
            
            # Simple logic: if days_of_week is present, strictly follow it.
            if days_of_week and (current_day.weekday() + 1) not in days_of_week:
                 # Note: User request example said "[1,3,5] for Mon/Wed/Fri". 
                 # Python weekday() is 0=Mon. So 1=Tue? 
                 # Let's assume standard 0-6 or 1-7. 
                 # Usually 1=Mon in general logic or ISO. 
                 # Let's assume 1=Mon, 2=Tue... 7=Sun to match the "1,3,5 Mon/Wed/Fri" example?
                 # If 1=Mon, 3=Wed, 5=Fri.
                 # Python .weekday(): Mon=0, Wed=2, Fri=4. 
                 # So we map (weekday() + 1).
                 # Let's stick to this assumption.
                 current_day += timedelta(days=1)
                 continue

            for time_str in times:
                try:
                    # Construct datetime
                    # time_str is "HH:MM"
                    h, m = map(int, time_str.split(':'))
                    scheduled_dt = datetime.combine(current_day, datetime.min.time()).replace(hour=h, minute=m)
                    
                    # If this time is in the past relative to start_time (on the first day), maybe skip?
                    # Or just generate it if it's today? 
                    # Requirements: "generate dose events for next N days".
                    # Usually implies future. But if I generate for "Today", I want untaken meds from morning too?
                    # Let's include everything from start_time onwards? 
                    # Or just purely date based. 
                    
                    # Check if already exists
                    existing = db.query(DoseEvent).filter(
                        DoseEvent.medication_id == med.id,
                        DoseEvent.scheduled_at == scheduled_dt
                    ).first()

                    if not existing:
                        new_event = DoseEvent(
                            medication_id=med.id,
                            scheduled_at=scheduled_dt,
                            status="PENDING"
                        )
                        db.add(new_event)
                        generated_count += 1
                except:
                    continue
            
            current_day += timedelta(days=1)
            
    db.commit()
    return generated_count

def process_missed_doses(db: Session, user_id: str):
    """
    Mark PENDING events as MISSED if grace period passed.
    """
    now = get_current_time()
    grace_period = timedelta(minutes=120)
    
    # Logic: Status == PENDING AND scheduled_at < now - 120 mins
    # We need to join Medication to filter by user_id
    pending_events = db.query(DoseEvent).join(Medication).filter(
        Medication.user_id == user_id,
        DoseEvent.status == "PENDING"
    ).all()

    updated_count = 0
    for event in pending_events:
        if event.scheduled_at + grace_period < now:
            event.status = "MISSED"
            updated_count += 1
            
    if updated_count > 0:
        db.commit()
    return updated_count
