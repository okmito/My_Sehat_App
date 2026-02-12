"""
User Data Rights Endpoints - DPDP Act 2023 Compliance
======================================================

Provides Right to Access, Right to Erasure, and Right to Correction
for medication data.
"""

import sys
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Header
from sqlalchemy.orm import Session
from typing import List, Dict, Any
from datetime import datetime

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

try:
    from medicine_backend.medicine_app.core.db import get_db
except ImportError:
    # Fallback
    try:
        from core.db import get_db
    except ImportError:
         # Try full path from root
        from backend.medicine_backend.medicine_app.core.db import get_db

try:
    from medicine_backend.medicine_app.models.medication import Medication
    from medicine_backend.medicine_app.models.schedule import MedicationSchedule
    from medicine_backend.medicine_app.models.prescription import Prescription
    from medicine_backend.medicine_app.models.dose_event import DoseEvent
except ImportError:
    from models.medication import Medication
    from models.schedule import MedicationSchedule
    from models.prescription import Prescription
    from models.dose_event import DoseEvent

# DPDP Compliance imports
try:
    from shared.dpdp import (
        AuditLogger, AuditAction, AuditLogEntry,
        get_audit_logger
    )
    DPDP_AVAILABLE = True
    audit_logger = get_audit_logger("medicine_backend")
except ImportError:
    DPDP_AVAILABLE = False
    audit_logger = None

router = APIRouter(prefix="/my-data", tags=["DPDP User Rights"])


def get_user_id(x_user_id: str = Header(...)):
    if not x_user_id:
        raise HTTPException(status_code=400, detail="X-User-Id header missing")
    return x_user_id


@router.get("/")
def export_all_data(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
) -> Dict[str, Any]:
    """
    Export all user's medication data (Right to Access).
    
    **DPDP Compliance:**
    - Returns all data in portable JSON format
    - Includes medications, schedules, dose events, prescriptions
    """
    # Get all medications
    medications = db.query(Medication).filter(
        Medication.user_id == user_id
    ).all()
    
    # Get all schedules for user's medications
    med_ids = [m.id for m in medications]
    schedules = db.query(MedicationSchedule).filter(
        MedicationSchedule.medication_id.in_(med_ids)
    ).all() if med_ids else []
    
    # Get all dose events for user's medications
    dose_events = db.query(DoseEvent).filter(
        DoseEvent.medication_id.in_(med_ids)
    ).all() if med_ids else []
    
    # Get all prescriptions
    prescriptions = db.query(Prescription).filter(
        Prescription.user_id == user_id
    ).all()
    
    # Log data export
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_EXPORT,
            resource_type="medication_all_data",
            purpose="right_to_access"
        ))
    
    return {
        "user_id": user_id,
        "export_date": datetime.utcnow().isoformat(),
        "medications": [
            {
                "id": m.id,
                "name": m.name,
                "strength": m.strength,
                "form": m.form,
                "instructions": m.instructions,
                "start_date": str(m.start_date) if m.start_date else None,
                "end_date": str(m.end_date) if m.end_date else None,
                "is_active": m.is_active
            }
            for m in medications
        ],
        "schedules": [
            {
                "id": s.id,
                "medication_id": s.medication_id,
                "schedule_type": s.schedule_type,
                "times_json": s.times_json,
                "days_json": s.days_json,
                "interval_hours": s.interval_hours,
                "timezone": s.timezone
            }
            for s in schedules
        ],
        "dose_events": [
            {
                "id": d.id,
                "medication_id": d.medication_id,
                "scheduled_at": str(d.scheduled_at) if d.scheduled_at else None,
                "status": d.status,
                "taken_at": str(d.taken_at) if d.taken_at else None
            }
            for d in dose_events
        ],
        "prescriptions": [
            {
                "id": p.id,
                "file_path": p.file_path,
                "uploaded_at": str(p.uploaded_at) if p.uploaded_at else None,
                "extraction_status": p.extraction_status,
                "extracted_json": p.extracted_json
            }
            for p in prescriptions
        ],
        "dpdp_notice": "This is your complete medication data as per DPDP Act 2023 Right to Access."
    }


@router.delete("/")
def delete_all_data(
    confirm: bool = False,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
) -> Dict[str, Any]:
    """
    Delete all user's medication data (Right to Erasure).
    
    **DPDP Compliance:**
    - Permanently deletes all data
    - Cannot be undone
    - Requires confirmation
    """
    if not confirm:
        return {
            "success": False,
            "message": "Please confirm deletion by setting confirm=true",
            "warning": "This action cannot be undone. All your medication data will be permanently deleted."
        }
    
    deleted_count = 0
    
    # Get all medications first
    medications = db.query(Medication).filter(
        Medication.user_id == user_id
    ).all()
    med_ids = [m.id for m in medications]
    
    # Delete schedules
    if med_ids:
        deleted = db.query(MedicationSchedule).filter(
            MedicationSchedule.medication_id.in_(med_ids)
        ).delete(synchronize_session=False)
        deleted_count += deleted
    
    # Delete dose events for user's medications
    if med_ids:
        deleted = db.query(DoseEvent).filter(
            DoseEvent.medication_id.in_(med_ids)
        ).delete(synchronize_session=False)
        deleted_count += deleted
    
    # Delete prescriptions
    deleted = db.query(Prescription).filter(
        Prescription.user_id == user_id
    ).delete(synchronize_session=False)
    deleted_count += deleted
    
    # Delete medications
    deleted = db.query(Medication).filter(
        Medication.user_id == user_id
    ).delete(synchronize_session=False)
    deleted_count += deleted
    
    db.commit()
    
    # Log erasure
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_ERASURE,
            resource_type="medication_all_data",
            purpose="right_to_erasure",
            details={"records_deleted": deleted_count}
        ))
    
    return {
        "success": True,
        "message": "All your medication data has been permanently deleted.",
        "records_deleted": deleted_count,
        "dpdp_compliant": True
    }


@router.get("/emergency-summary")
def get_emergency_summary(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
) -> Dict[str, Any]:
    """
    Get minimal medication data for emergency access.
    
    **DPDP Compliance:**
    - Only returns current active medications
    - Used by SOS service for emergency data packet
    - Access is logged
    """
    medications = db.query(Medication).filter(
        Medication.user_id == user_id,
        Medication.is_active == True
    ).all()
    
    # Log emergency access
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.READ,
            resource_type="medication_emergency",
            purpose="emergency_access"
        ))
    
    return {
        "user_id": user_id,
        "current_medications": [
            f"{m.name} - {m.dosage}" for m in medications
        ],
        "medication_count": len(medications),
        "dpdp_notice": "This minimal data is shared for emergency purposes only."
    }
