"""
FHIR MedicationRequest Endpoint
================================

GET /fhir/MedicationRequest?patient={id} - Get medications in FHIR format

All access requires valid DPDP consent and is audit logged.
"""

from fastapi import APIRouter, HTTPException, Header, Query
from typing import Optional
from datetime import datetime, date
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent.parent))

from fhir_backend.fhir_app.models import (
    FHIRMedicationRequest, FHIRBundle, FHIROperationOutcome,
    OperationOutcomeIssue, BundleEntry, BundleType
)
from fhir_backend.fhir_app.core import map_medication_to_fhir_medication_request

try:
    from shared.dpdp.consent import ConsentEngine, DataCategory, Purpose, GrantedTo, ConsentCheck
    from shared.dpdp.audit import AuditLogger, AuditAction
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False

router = APIRouter()

# Initialize consent engine with correct shared database path
if DPDP_AVAILABLE:
    import os
    _db_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    _consent_db = os.path.join(_db_base, '..', '..', '..', '..', 'shared', 'consent.db')
    _audit_db = os.path.join(_db_base, '..', '..', '..', '..', 'shared', 'audit.db')
    consent_engine = ConsentEngine(f"sqlite:///{os.path.abspath(_consent_db)}")
    audit_logger = AuditLogger(f"sqlite:///{os.path.abspath(_audit_db)}")
else:
    consent_engine = None
    audit_logger = None


def _create_operation_outcome(severity: str, code: str, message: str) -> dict:
    return FHIROperationOutcome(
        issue=[OperationOutcomeIssue(
            severity=severity,
            code=code,
            diagnostics=message
        )]
    ).model_dump(by_alias=True, exclude_none=True)


async def verify_consent(patient_id: str, hospital_id: str) -> tuple[bool, Optional[int], Optional[str]]:
    if not DPDP_AVAILABLE or not consent_engine:
        return True, None, "Demo mode"
    
    try:
        check = ConsentCheck(
            user_id=patient_id,
            data_category=DataCategory.HEALTH_RECORDS,
            purpose=Purpose.SHARING,
            granted_to=GrantedTo.HOSPITAL
        )
        result = consent_engine.check_consent(check)
        return result.is_valid, result.consent_id, result.reason
    except Exception as e:
        return False, None, str(e)


async def log_access(
    patient_id: str, hospital_id: str, resource_type: str,
    consent_id: Optional[int], success: bool, reason: Optional[str] = None
):
    if not audit_logger:
        return
    try:
        audit_logger.log(
            user_id=patient_id,
            action=AuditAction.READ if success else AuditAction.ACCESS_DENIED,
            resource_type=f"FHIR_{resource_type}",
            resource_id=patient_id,
            actor_id=hospital_id,
            actor_type="hospital",
            purpose="hospital_access",
            consent_id=consent_id,
            data_categories=["medications"],
            service_name="fhir_backend",
            success=success,
            error_message=reason if not success else None
        )
    except Exception as e:
        print(f"[FHIR Audit] Log failed: {e}")


# Mock medication data
MOCK_MEDICATIONS = {
    "patient-001": [
        {
            "medication_id": "med-001",
            "medication_name": "Metformin",
            "dosage": "500mg",
            "frequency": "Twice daily (morning and evening)",
            "form": "tablet",
            "instructions": "Take with food",
            "start_date": date(2023, 1, 15),
            "end_date": None,
            "prescriber_name": "Dr. Anil Mehta",
            "is_active": True
        },
        {
            "medication_id": "med-002",
            "medication_name": "Amlodipine",
            "dosage": "5mg",
            "frequency": "Once daily (morning)",
            "form": "tablet",
            "instructions": "Take on empty stomach",
            "start_date": date(2023, 3, 1),
            "end_date": None,
            "prescriber_name": "Dr. Anil Mehta",
            "is_active": True
        },
        {
            "medication_id": "med-003",
            "medication_name": "Aspirin",
            "dosage": "75mg",
            "frequency": "Once daily",
            "form": "tablet",
            "instructions": "Take after lunch",
            "start_date": date(2023, 6, 15),
            "end_date": date(2023, 12, 15),
            "prescriber_name": "Dr. Sunita Rao",
            "is_active": False
        }
    ],
    "patient-002": [
        {
            "medication_id": "med-004",
            "medication_name": "Clopidogrel",
            "dosage": "75mg",
            "frequency": "Once daily",
            "form": "tablet",
            "instructions": "Take after dinner",
            "start_date": date(2023, 2, 1),
            "end_date": None,
            "prescriber_name": "Dr. Cardiac Specialist",
            "is_active": True
        },
        {
            "medication_id": "med-005",
            "medication_name": "Atorvastatin",
            "dosage": "20mg",
            "frequency": "Once daily at bedtime",
            "form": "tablet",
            "instructions": "Take at night",
            "start_date": date(2023, 2, 1),
            "end_date": None,
            "prescriber_name": "Dr. Cardiac Specialist",
            "is_active": True
        }
    ]
}


@router.get("")
async def search_medication_requests(
    patient: str = Query(..., description="Patient ID"),
    status: Optional[str] = Query(None, description="Filter by status (active, completed)"),
    _count: Optional[int] = Query(100, description="Maximum results"),
    x_hospital_id: str = Header(..., description="Hospital ID"),
    x_doctor_id: Optional[str] = Header(None, description="Doctor ID"),
):
    """
    Search medication requests for a patient in FHIR R4 format.
    
    Returns a FHIR Bundle containing MedicationRequest resources.
    Requires valid DPDP consent for medication data.
    """
    # Verify consent
    is_valid, consent_id, reason = await verify_consent(patient, x_hospital_id)
    
    if not is_valid:
        await log_access(patient, x_hospital_id, "MedicationRequest", consent_id, False, reason)
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome(
                "error", "forbidden",
                f"Access denied: {reason or 'No consent for medication data'}"
            )
        )
    
    # Get medication data
    medications = MOCK_MEDICATIONS.get(patient, [])
    
    # Apply status filter if provided
    if status:
        if status.lower() == "active":
            medications = [m for m in medications if m.get("is_active", True)]
        elif status.lower() == "completed":
            medications = [m for m in medications if not m.get("is_active", True)]
    
    # Map to FHIR MedicationRequests
    entries = []
    for med in medications[:_count]:
        med_request = map_medication_to_fhir_medication_request(
            patient_id=patient,
            **med
        )
        entries.append(BundleEntry(
            fullUrl=f"urn:uuid:{med_request.id}",
            resource=med_request.model_dump(by_alias=True, exclude_none=True)
        ))
    
    # Log access
    await log_access(patient, x_hospital_id, "MedicationRequest", consent_id, True)
    
    # Return as FHIR Bundle
    bundle = FHIRBundle(
        id=f"medications-{patient}",
        type=BundleType.SEARCHSET,
        total=len(entries),
        timestamp=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+05:30"),
        entry=entries
    )
    
    return bundle.model_dump(by_alias=True, exclude_none=True)


@router.get("/{medication_id}")
async def get_medication_request(
    medication_id: str,
    x_hospital_id: str = Header(..., description="Hospital ID"),
    x_patient_id: str = Header(..., description="Patient ID for consent check"),
):
    """Get a specific medication request by ID"""
    is_valid, consent_id, reason = await verify_consent(x_patient_id, x_hospital_id)
    
    if not is_valid:
        await log_access(x_patient_id, x_hospital_id, "MedicationRequest", consent_id, False, reason)
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome("error", "forbidden", f"Access denied: {reason}")
        )
    
    # Search for medication
    for patient_id, medications in MOCK_MEDICATIONS.items():
        for med in medications:
            if med["medication_id"] == medication_id:
                med_request = map_medication_to_fhir_medication_request(patient_id=patient_id, **med)
                await log_access(x_patient_id, x_hospital_id, "MedicationRequest", consent_id, True)
                return med_request.model_dump(by_alias=True, exclude_none=True)
    
    raise HTTPException(
        status_code=404,
        detail=_create_operation_outcome("error", "not-found", f"MedicationRequest {medication_id} not found")
    )
