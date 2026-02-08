import sys
from pathlib import Path
from sqlalchemy.orm import Session
import json

# Ensure parent is in path for absolute imports
_parent_dir = Path(__file__).resolve().parent.parent.parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

from medicine_backend.medicine_app.models.prescription import Prescription
from medicine_backend.medicine_app.models.medication import Medication
from medicine_backend.medicine_app.models.schedule import MedicationSchedule

def confirm_prescription(db: Session, prescription_id: int, medications_data: list, user_id: str):
    """
    Confirm prescription and create medications from it.
    """
    prescription = db.query(Prescription).filter(
        Prescription.id == prescription_id,
        Prescription.user_id == user_id
    ).first()
    
    if not prescription:
        return None

    # Update prescription status
    prescription.extraction_status = "CONFIRMED"
    # Optionally store the confirmed data as JSON
    # prescription.extracted_json = json.dumps(medications_data) 
    
    created_meds = []
    
    for med_data in medications_data:
        # Create Medication
        new_med = Medication(
            user_id=user_id,
            name=med_data.get("name"),
            strength=med_data.get("strength"),
            form=med_data.get("form"),
            instructions=med_data.get("instructions"),
            is_active=True
        )
        db.add(new_med)
        db.flush() # get ID
        
        # Create Schedule
        times = med_data.get("times", [])
        schedule_type = med_data.get("schedule_type", "DAILY")
        
        if times:
            new_schedule = MedicationSchedule(
                medication_id=new_med.id,
                schedule_type=schedule_type,
                times_json=json.dumps(times),
                days_json=json.dumps(med_data.get("days", [])),
                timezone="Asia/Kolkata"
            )
            db.add(new_schedule)
            
        created_meds.append(new_med)
        
    db.commit()
    return created_meds
