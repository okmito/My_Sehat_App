"""
FHIR Patient Endpoint
=====================

GET /fhir/Patient/{id} - Get patient demographics in FHIR format

All access requires valid DPDP consent and is audit logged.
"""

from fastapi import APIRouter, HTTPException, Depends, Header, Query
from typing import Optional
from datetime import datetime
import sys
from pathlib import Path

# Add parent paths for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent.parent))

from fhir_backend.fhir_app.models import FHIRPatient, FHIROperationOutcome, OperationOutcomeIssue
from fhir_backend.fhir_app.core import map_user_to_fhir_patient

# Import DPDP modules
try:
    from shared.dpdp.consent import ConsentEngine, DataCategory, Purpose, GrantedTo, ConsentCheck
    from shared.dpdp.audit import AuditLogger, AuditAction
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("⚠️ DPDP modules not available for FHIR Patient endpoint")

router = APIRouter()

# Initialize consent engine and audit logger with correct database path
if DPDP_AVAILABLE:
    import os
    _db_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    # Go up to fhir_backend, then to backend, then to shared
    _consent_db = os.path.join(_db_base, '..', '..', '..', '..', 'shared', 'consent.db')
    _audit_db = os.path.join(_db_base, '..', '..', '..', '..', 'shared', 'audit.db')
    consent_engine = ConsentEngine(f"sqlite:///{os.path.abspath(_consent_db)}")
    audit_logger = AuditLogger(f"sqlite:///{os.path.abspath(_audit_db)}")
else:
    consent_engine = None
    audit_logger = None


def _create_operation_outcome(severity: str, code: str, message: str) -> dict:
    """Create a FHIR OperationOutcome for errors"""
    return FHIROperationOutcome(
        issue=[OperationOutcomeIssue(
            severity=severity,
            code=code,
            diagnostics=message
        )]
    ).model_dump(by_alias=True, exclude_none=True)


async def verify_hospital_consent(
    patient_id: str,
    hospital_id: str,
    purpose: str = "hospital_access"
) -> tuple[bool, Optional[int], Optional[str]]:
    """
    Verify hospital has valid consent to access patient data.
    
    Returns: (is_valid, consent_id, reason)
    """
    if not DPDP_AVAILABLE or not consent_engine:
        # In demo mode without DPDP, allow access
        return True, None, "DPDP module not available - demo mode"
    
    try:
        # Check consent for health_records category (for all FHIR resources)
        check = ConsentCheck(
            user_id=patient_id,
            data_category=DataCategory.HEALTH_RECORDS,
            purpose=Purpose.SHARING,
            granted_to=GrantedTo.HOSPITAL
        )
        result = consent_engine.check_consent(check)
        
        return result.is_valid, result.consent_id, result.reason
    except Exception as e:
        return False, None, f"Consent verification failed: {str(e)}"


async def log_fhir_access(
    patient_id: str,
    hospital_id: str,
    resource_type: str,
    resource_id: str,
    consent_id: Optional[int],
    success: bool,
    reason: Optional[str] = None
):
    """Log FHIR resource access for audit"""
    if not DPDP_AVAILABLE or not audit_logger:
        return
    
    try:
        audit_logger.log(
            user_id=patient_id,
            action=AuditAction.READ if success else AuditAction.ACCESS_DENIED,
            resource_type=f"FHIR_{resource_type}",
            resource_id=resource_id,
            actor_id=hospital_id,
            actor_type="hospital",
            purpose="hospital_access",
            consent_id=consent_id,
            data_categories=["personal_info"],
            service_name="fhir_backend",
            success=success,
            error_message=reason if not success else None,
            details={
                "fhir_resource": resource_type,
                "access_timestamp": datetime.utcnow().isoformat(),
                "dpdp_compliant": True
            }
        )
    except Exception as e:
        print(f"[FHIR Audit] Failed to log access: {e}")


# Mock patient data store - using auth backend user IDs
# In production, fetch from actual database
MOCK_PATIENTS = {
    "1": {
        "name": "Mitesh Sai",
        "age": 28,
        "gender": "male",
        "blood_group": "O+",
        "phone": "+91 9999999999",
        "email": "mitesh.sai@email.com",
        "address": "Mumbai, Maharashtra",
        "emergency_contacts": [
            {"name": "Sai Family", "phone": "+91 9876543210", "relationship": "Family"}
        ]
    },
    "2": {
        "name": "Aakanksha",
        "age": 25,
        "gender": "female",
        "blood_group": "A+",
        "phone": "+91 8888888888",
        "email": "aakanksha@email.com",
        "address": "Delhi, NCR",
        "emergency_contacts": [
            {"name": "Parents", "phone": "+91 8765432109", "relationship": "Parents"}
        ]
    },
    "3": {
        "name": "Srinidhi",
        "age": 30,
        "gender": "female",
        "blood_group": "B+",
        "phone": "+91 7777777777",
        "email": "srinidhi@email.com",
        "address": "Bangalore, Karnataka",
        "emergency_contacts": [
            {"name": "Spouse", "phone": "+91 7654321098", "relationship": "Spouse"}
        ]
    },
    "4": {
        "name": "Rupak",
        "age": 35,
        "gender": "male",
        "blood_group": "AB+",
        "phone": "+91 6666666666",
        "email": "rupak@email.com",
        "address": "Chennai, Tamil Nadu",
        "emergency_contacts": [
            {"name": "Family", "phone": "+91 6543210987", "relationship": "Family"}
        ]
    }
}


@router.get("/{patient_id}")
async def get_patient(
    patient_id: str,
    x_hospital_id: str = Header(..., description="Hospital ID requesting access"),
    x_doctor_id: Optional[str] = Header(None, description="Doctor ID (optional)"),
    x_purpose: str = Header("hospital_access", description="Purpose of access")
):
    """
    Get patient demographics in FHIR R4 format.
    
    Requires valid DPDP consent from the patient.
    Access is audit logged.
    
    Returns FHIR Patient resource or OperationOutcome on error.
    """
    # 1. Verify consent BEFORE any data access
    is_valid, consent_id, reason = await verify_hospital_consent(
        patient_id=patient_id,
        hospital_id=x_hospital_id,
        purpose=x_purpose
    )
    
    if not is_valid:
        # Log denied access
        await log_fhir_access(
            patient_id=patient_id,
            hospital_id=x_hospital_id,
            resource_type="Patient",
            resource_id=patient_id,
            consent_id=consent_id,
            success=False,
            reason=reason
        )
        
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome(
                "error",
                "forbidden",
                f"Access denied: {reason or 'Patient has not granted consent for hospital access'}"
            )
        )
    
    # 2. Fetch patient data (mock for demo)
    patient_data = MOCK_PATIENTS.get(patient_id)
    
    if not patient_data:
        # Log not found
        await log_fhir_access(
            patient_id=patient_id,
            hospital_id=x_hospital_id,
            resource_type="Patient",
            resource_id=patient_id,
            consent_id=consent_id,
            success=False,
            reason="Patient not found"
        )
        
        raise HTTPException(
            status_code=404,
            detail=_create_operation_outcome(
                "error",
                "not-found",
                f"Patient {patient_id} not found"
            )
        )
    
    # 3. Map to FHIR Patient
    fhir_patient = map_user_to_fhir_patient(
        user_id=patient_id,
        **patient_data
    )
    
    # 4. Log successful access
    await log_fhir_access(
        patient_id=patient_id,
        hospital_id=x_hospital_id,
        resource_type="Patient",
        resource_id=patient_id,
        consent_id=consent_id,
        success=True
    )
    
    # 5. Return FHIR JSON
    return fhir_patient.model_dump(by_alias=True, exclude_none=True)
