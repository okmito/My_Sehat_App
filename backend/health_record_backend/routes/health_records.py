"""
Health Record API Routes
DPDP-compliant medical document analysis endpoints
"""
import base64
import os
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, File, Form, UploadFile, HTTPException, Query
from sqlalchemy.orm import Session

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.db import get_db
from core.config import settings
from models.schemas import (
    DocumentAnalysisResponse,
    HealthRecordResponse,
    HealthRecordListResponse,
    TimelineResponse,
    TimelineEntry,
    SearchRequest,
    EmergencyDataResponse,
    ConsentRequest,
    ConsentResponse,
    VerificationRequest,
    StorageType,
    DocumentType
)
from services.document_analysis import document_analysis_service
from services.health_record_service import health_record_service

router = APIRouter(prefix="/health-records", tags=["Health Records"])


@router.post("/analyze", response_model=DocumentAnalysisResponse)
async def analyze_document(
    file: UploadFile = File(...),
    user_id: str = Form(...),
):
    """
    Analyze a medical document and extract structured information.
    Returns extracted data for user verification before storage.
    
    This endpoint does NOT store the document - it only analyzes it.
    Use /save endpoint after user verification to store.
    """
    # Validate file type
    file_ext = os.path.splitext(file.filename)[1].lower()
    if file_ext not in settings.ALLOWED_EXTENSIONS:
        raise HTTPException(
            status_code=400,
            detail=f"File type not allowed. Allowed: {settings.ALLOWED_EXTENSIONS}"
        )
    
    # Read file content
    content = await file.read()
    
    # Check file size
    if len(content) > settings.MAX_FILE_SIZE_MB * 1024 * 1024:
        raise HTTPException(
            status_code=400,
            detail=f"File too large. Maximum size: {settings.MAX_FILE_SIZE_MB}MB"
        )
    
    # Convert to base64 for analysis
    image_base64 = base64.b64encode(content).decode('utf-8')
    
    try:
        # Analyze document
        if file_ext == ".pdf":
            # Use PDF analysis
            result = await document_analysis_service.analyze_pdf(content)
        else:
            result = await document_analysis_service.analyze_document(
                image_base64, 
                file_type=file_ext.replace(".", "")
            )
        
        return result
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/save", response_model=HealthRecordResponse)
async def save_health_record(
    file: UploadFile = File(...),
    user_id: str = Form(...),
    document_type: str = Form(...),
    document_date: Optional[str] = Form(None),
    doctor_name: Optional[str] = Form(None),
    hospital_name: Optional[str] = Form(None),
    patient_name: Optional[str] = Form(None),
    diagnosis: Optional[str] = Form(None),
    notes: Optional[str] = Form(None),
    medications_json: Optional[str] = Form(None),
    test_results_json: Optional[str] = Form(None),
    storage_type: str = Form("permanent"),
    consent_given: bool = Form(False),
    db: Session = Depends(get_db)
):
    """
    Save a verified health record.
    User must confirm consent before storage.
    """
    if not consent_given:
        raise HTTPException(
            status_code=400,
            detail="Consent is required to store health records."
        )
    
    # Parse storage type
    try:
        storage = StorageType(storage_type)
    except ValueError:
        storage = StorageType.PERMANENT
    
    if storage == StorageType.DO_NOT_STORE:
        return HTTPException(
            status_code=400,
            detail="User chose not to store the document."
        )
    
    # Read and save file
    content = await file.read()
    image_base64 = base64.b64encode(content).decode('utf-8')
    
    # Re-analyze to get structured data
    try:
        analysis = await document_analysis_service.analyze_document(
            image_base64,
            file_type=os.path.splitext(file.filename)[1].replace(".", "")
        )
    except Exception:
        # Use provided data if analysis fails
        from models.schemas import DocumentAnalysisResponse
        analysis = DocumentAnalysisResponse(
            document_type=document_type,
            date=document_date,
            doctor=doctor_name,
            hospital=hospital_name,
            patient_name=patient_name,
            diagnosis=diagnosis,
            notes=notes,
            overall_confidence=0.5
        )
    
    # Override with user-verified data
    analysis.document_type = document_type
    if document_date:
        analysis.date = document_date
    if doctor_name:
        analysis.doctor = doctor_name
    if hospital_name:
        analysis.hospital = hospital_name
    if patient_name:
        analysis.patient_name = patient_name
    if diagnosis:
        analysis.diagnosis = diagnosis
    if notes:
        analysis.notes = notes
    
    # Create record
    record = health_record_service.create_from_analysis(
        db=db,
        user_id=user_id,
        analysis=analysis,
        storage_type=storage,
        consent_given=consent_given,
        raw_text=image_base64[:1000]  # Store truncated for reference
    )
    
    return record


@router.get("/list", response_model=List[HealthRecordListResponse])
async def list_health_records(
    user_id: str = Query(...),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(get_db)
):
    """Get all health records for a user"""
    records = health_record_service.get_user_records(db, user_id, skip, limit)
    return records


@router.get("/timeline", response_model=TimelineResponse)
async def get_timeline(
    user_id: str = Query(...),
    db: Session = Depends(get_db)
):
    """Get health records as a chronological timeline"""
    records = health_record_service.get_timeline(db, user_id)
    
    entries = []
    for record in records:
        title = f"{record.document_type.replace('_', ' ').title()}"
        if record.diagnosis:
            title = record.diagnosis[:50]
        
        # Use document_date if available, otherwise fall back to upload_date
        entry_date = record.document_date or record.upload_date
        
        entries.append(TimelineEntry(
            id=record.id,
            date=entry_date,
            document_type=record.document_type,
            title=title,
            doctor_name=record.doctor_name,
            hospital_name=record.hospital_name
        ))
    
    return TimelineResponse(entries=entries, total_count=len(entries))


@router.get("/{record_id}", response_model=HealthRecordResponse)
async def get_health_record(
    record_id: int,
    user_id: str = Query(...),
    db: Session = Depends(get_db)
):
    """Get a specific health record by ID"""
    record = health_record_service.get_by_id(db, record_id, user_id)
    if not record:
        raise HTTPException(status_code=404, detail="Health record not found")
    return record


@router.post("/search", response_model=List[HealthRecordListResponse])
async def search_records(
    search: SearchRequest,
    db: Session = Depends(get_db)
):
    """
    Search health records with filters:
    - By document type
    - By doctor/hospital name
    - By date range
    - By medication name
    - Full text search
    """
    records = health_record_service.search_records(db, search)
    return records


@router.post("/{record_id}/verify", response_model=HealthRecordResponse)
async def verify_record(
    record_id: int,
    verification: VerificationRequest,
    db: Session = Depends(get_db)
):
    """Mark a record as verified after user review"""
    record = health_record_service.verify_record(
        db, 
        record_id, 
        verification.user_id,
        verification.verified_data.model_dump(exclude_none=True)
    )
    if not record:
        raise HTTPException(status_code=404, detail="Health record not found")
    return record


@router.delete("/{record_id}")
async def delete_record(
    record_id: int,
    user_id: str = Query(...),
    db: Session = Depends(get_db)
):
    """Delete a health record (soft delete with audit log)"""
    success = health_record_service.delete_record(db, record_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Health record not found")
    return {"message": "Health record deleted successfully"}


@router.post("/{record_id}/revoke-consent")
async def revoke_consent(
    record_id: int,
    user_id: str = Query(...),
    db: Session = Depends(get_db)
):
    """Revoke consent and delete associated data - DPDP compliance"""
    success = health_record_service.revoke_consent(db, record_id, user_id)
    if not success:
        raise HTTPException(status_code=404, detail="Health record not found")
    return {"message": "Consent revoked and data deleted successfully"}


@router.get("/emergency/{user_id}", response_model=EmergencyDataResponse)
async def get_emergency_data(
    user_id: str,
    db: Session = Depends(get_db)
):
    """
    Get only life-critical health information for emergency access.
    Returns: blood group, allergies, chronic conditions.
    
    **DPDP Compliance:**
    - Emergency responders see only life-critical information, nothing else
    - Access is logged for audit trail
    """
    data = health_record_service.get_emergency_data(db, user_id)
    return EmergencyDataResponse(**data)


@router.post("/{record_id}/emergency-access")
async def set_emergency_access(
    record_id: int,
    user_id: str = Query(...),
    accessible: bool = Query(...),
    db: Session = Depends(get_db)
):
    """Set whether record's critical info is accessible during emergencies"""
    success = health_record_service.set_emergency_accessible(
        db, record_id, user_id, accessible
    )
    if not success:
        raise HTTPException(status_code=404, detail="Health record not found")
    return {"message": f"Emergency access {'enabled' if accessible else 'disabled'}"}


@router.post("/cleanup-expired")
async def cleanup_expired_records(
    db: Session = Depends(get_db)
):
    """Clean up records past their auto-delete date (for temporary storage)"""
    count = health_record_service.cleanup_expired_records(db)
    return {"message": f"Cleaned up {count} expired records"}


# ============================================================================
# DPDP USER DATA RIGHTS ENDPOINTS
# ============================================================================

@router.get("/my-data/{user_id}")
async def export_all_user_data(
    user_id: str,
    db: Session = Depends(get_db)
):
    """
    Export all user's health record data (Right to Access).
    
    **DPDP Compliance:**
    - Returns complete data in portable JSON format
    - Includes all records, medications, test results
    - Audit logged
    """
    # Get all records
    records = health_record_service.get_user_records(db, user_id)
    
    return {
        "user_id": user_id,
        "export_date": datetime.utcnow().isoformat(),
        "total_records": len(records),
        "records": [
            {
                "id": r.id,
                "document_type": r.document_type,
                "document_date": str(r.document_date) if r.document_date else None,
                "doctor_name": r.doctor_name,
                "hospital_name": r.hospital_name,
                "patient_name": r.patient_name,
                "diagnosis": r.diagnosis,
                "notes": r.notes,
                "storage_type": r.storage_type,
                "upload_date": str(r.upload_date) if r.upload_date else None,
                "medications": [
                    {
                        "name": m.medication_name,
                        "dosage": m.dosage,
                        "frequency": m.frequency,
                        "duration": m.duration
                    } for m in (r.medications or [])
                ],
                "test_results": [
                    {
                        "name": t.test_name,
                        "value": t.value,
                        "unit": t.unit,
                        "reference_range": t.reference_range,
                        "status": t.status
                    } for t in (r.test_results or [])
                ],
                "critical_info": {
                    "blood_group": r.critical_info.blood_group if r.critical_info else None,
                    "allergies": r.critical_info.allergies if r.critical_info else None,
                    "chronic_conditions": r.critical_info.chronic_conditions if r.critical_info else None
                } if r.critical_info else None
            }
            for r in records
        ],
        "dpdp_notice": "This is your complete health record data as per DPDP Act 2023 Right to Access."
    }


@router.delete("/my-data/{user_id}")
async def delete_all_user_data(
    user_id: str,
    confirm: bool = Query(False),
    db: Session = Depends(get_db)
):
    """
    Delete all user's health record data (Right to Erasure).
    
    **DPDP Compliance:**
    - Permanently deletes all records
    - Cannot be undone
    - Requires confirmation
    """
    if not confirm:
        return {
            "success": False,
            "message": "Please confirm deletion by setting confirm=true",
            "warning": "This action cannot be undone. All your health records will be permanently deleted."
        }
    
    deleted_count = health_record_service.delete_all_user_records(db, user_id)
    
    return {
        "success": True,
        "message": "All your health records have been permanently deleted.",
        "records_deleted": deleted_count,
        "dpdp_compliant": True
    }


@router.get("/my-data/{user_id}/audit-trail")
async def get_access_audit_trail(
    user_id: str,
    db: Session = Depends(get_db)
):
    """
    Get audit trail of who accessed user's health records.
    
    **DPDP Compliance:**
    - User transparency on data access
    - Shows who accessed what and when
    """
    # Get consent logs which track access
    from models.health_record import ConsentLog
    logs = db.query(ConsentLog).filter(
        ConsentLog.user_id == user_id
    ).order_by(ConsentLog.timestamp.desc()).all()
    
    return {
        "user_id": user_id,
        "access_history": [
            {
                "record_id": log.health_record_id,
                "action": log.action,
                "purpose": log.purpose,
                "timestamp": str(log.timestamp) if log.timestamp else None
            }
            for log in logs
        ],
        "dpdp_notice": "This shows all access to your health records."
    }

