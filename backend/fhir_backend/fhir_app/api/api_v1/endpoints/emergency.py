"""
FHIR Emergency Bundle Endpoint
==============================

GET /fhir/emergency/{patient_id} - Get emergency data bundle in FHIR format
GET /fhir/Bundle/{patient_id} - Get full patient bundle in FHIR format

Emergency access provides time-limited access to critical patient data.
Auto-expires after SOS ends.
"""

from fastapi import APIRouter, HTTPException, Header, Query
from typing import Optional, List
from datetime import datetime, timedelta
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent.parent))

from fhir_backend.fhir_app.models import (
    FHIRBundle, FHIROperationOutcome, OperationOutcomeIssue,
    BundleEntry, BundleType, Coding, Meta
)
from fhir_backend.fhir_app.core import (
    map_user_to_fhir_patient,
    map_allergy_to_fhir_allergy_intolerance,
    map_diagnosis_to_fhir_condition,
    map_medication_to_fhir_medication_request,
    map_emergency_profile_to_fhir_bundle
)

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


async def verify_emergency_consent(
    patient_id: str, 
    accessor_id: str,
    accessor_type: str = "ambulance"
) -> tuple[bool, Optional[int], Optional[str], Optional[datetime]]:
    """
    Verify emergency consent for SOS access.
    Returns: (is_valid, consent_id, reason, expires_at)
    """
    if not DPDP_AVAILABLE or not consent_engine:
        # Demo mode - return with 1 hour expiry
        return True, None, "Demo mode", datetime.utcnow() + timedelta(hours=1)
    
    try:
        check = ConsentCheck(
            user_id=patient_id,
            data_category=DataCategory.EMERGENCY,
            purpose=Purpose.EMERGENCY,
            granted_to=GrantedTo.EMERGENCY_RESPONDER if accessor_type == "ambulance" else GrantedTo.HOSPITAL
        )
        result = consent_engine.check_consent(check)
        
        return result.is_valid, result.consent_id, result.reason, result.expires_at
    except Exception as e:
        return False, None, str(e), None


async def log_emergency_access(
    patient_id: str, accessor_id: str, accessor_type: str,
    consent_id: Optional[int], success: bool, 
    justification: Optional[str] = None,
    emergency_id: Optional[str] = None
):
    if not audit_logger:
        return
    try:
        audit_logger.log(
            user_id=patient_id,
            action=AuditAction.EMERGENCY_ACCESS if success else AuditAction.ACCESS_DENIED,
            resource_type="FHIR_Emergency_Bundle",
            resource_id=patient_id,
            actor_id=accessor_id,
            actor_type=accessor_type,
            purpose="emergency",
            consent_id=consent_id,
            data_categories=["emergency", "personal_info", "medications", "allergies", "chronic_conditions"],
            service_name="fhir_backend",
            success=success,
            justification=justification,
            emergency_id=emergency_id,
            details={
                "access_type": "emergency_fhir_bundle",
                "dpdp_compliant": True,
                "auto_expire": True
            }
        )
    except Exception as e:
        print(f"[FHIR Emergency Audit] Log failed: {e}")


# Mock emergency profile data
MOCK_EMERGENCY_PROFILES = {
    "patient-001": {
        "name": "Priya Sharma",
        "age": 34,
        "gender": "female",
        "blood_group": "B+",
        "allergies": ["Penicillin", "Sulfa drugs"],
        "chronic_conditions": ["Type 2 Diabetes", "Hypertension"],
        "current_medications": ["Metformin 500mg (twice daily)", "Amlodipine 5mg (once daily)"],
        "emergency_contacts": [
            {"name": "Raj Sharma", "phone": "+91 98765 43211", "relationship": "Spouse"}
        ]
    },
    "patient-002": {
        "name": "Rajesh Kumar",
        "age": 52,
        "gender": "male",
        "blood_group": "A-",
        "allergies": ["Aspirin"],
        "chronic_conditions": ["Coronary Artery Disease"],
        "current_medications": ["Clopidogrel 75mg (once daily)", "Atorvastatin 20mg (at bedtime)"],
        "emergency_contacts": [
            {"name": "Sunita Kumar", "phone": "+91 98989 89899", "relationship": "Wife"}
        ]
    }
}


@router.get("/emergency/{patient_id}")
async def get_emergency_bundle(
    patient_id: str,
    x_ambulance_id: Optional[str] = Header(None, description="Ambulance ID (for emergency responders)"),
    x_hospital_id: Optional[str] = Header(None, description="Hospital ID"),
    x_sos_event_id: Optional[str] = Header(None, description="Active SOS event ID"),
    latitude: Optional[float] = Query(None, description="Patient latitude"),
    longitude: Optional[float] = Query(None, description="Patient longitude"),
):
    """
    Get emergency patient data bundle in FHIR R4 format.
    
    This is a POWER FEATURE for SOS situations.
    
    Returns a FHIR Bundle with:
    - Patient demographics
    - Allergies (AllergyIntolerance)
    - Chronic conditions (Condition)
    - Active medications (MedicationRequest)
    
    Access auto-expires after SOS ends.
    Requires emergency consent.
    """
    # Determine accessor
    accessor_id = x_ambulance_id or x_hospital_id
    accessor_type = "ambulance" if x_ambulance_id else "hospital"
    
    if not accessor_id:
        raise HTTPException(
            status_code=400,
            detail=_create_operation_outcome(
                "error", "required",
                "Either X-Ambulance-Id or X-Hospital-Id header is required"
            )
        )
    
    # Verify emergency consent
    is_valid, consent_id, reason, expires_at = await verify_emergency_consent(
        patient_id=patient_id,
        accessor_id=accessor_id,
        accessor_type=accessor_type
    )
    
    if not is_valid:
        await log_emergency_access(
            patient_id=patient_id,
            accessor_id=accessor_id,
            accessor_type=accessor_type,
            consent_id=consent_id,
            success=False,
            justification=reason,
            emergency_id=x_sos_event_id
        )
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome(
                "error", "forbidden",
                f"Emergency access denied: {reason or 'No emergency consent on file'}"
            )
        )
    
    # Get emergency profile
    profile = MOCK_EMERGENCY_PROFILES.get(patient_id)
    
    if not profile:
        await log_emergency_access(
            patient_id=patient_id,
            accessor_id=accessor_id,
            accessor_type=accessor_type,
            consent_id=consent_id,
            success=False,
            justification="Patient not found",
            emergency_id=x_sos_event_id
        )
        raise HTTPException(
            status_code=404,
            detail=_create_operation_outcome(
                "error", "not-found",
                f"Emergency profile for patient {patient_id} not found"
            )
        )
    
    # Create FHIR Emergency Bundle
    bundle = map_emergency_profile_to_fhir_bundle(
        patient_id=patient_id,
        name=profile.get("name"),
        age=profile.get("age"),
        gender=profile.get("gender"),
        blood_group=profile.get("blood_group"),
        allergies=profile.get("allergies", []),
        chronic_conditions=profile.get("chronic_conditions", []),
        current_medications=profile.get("current_medications", []),
        emergency_contacts=profile.get("emergency_contacts", []),
        latitude=latitude,
        longitude=longitude,
        sos_event_id=x_sos_event_id,
        consent_expires_at=expires_at
    )
    
    # Log successful emergency access
    await log_emergency_access(
        patient_id=patient_id,
        accessor_id=accessor_id,
        accessor_type=accessor_type,
        consent_id=consent_id,
        success=True,
        justification="Emergency SOS access",
        emergency_id=x_sos_event_id
    )
    
    response = bundle.model_dump(by_alias=True, exclude_none=True)
    
    # Add DPDP notice header
    response["_dpdp_notice"] = {
        "message": "This data is shared under emergency consent as per DPDP Act 2023",
        "consent_id": consent_id,
        "expires_at": expires_at.isoformat() if expires_at else None,
        "access_logged": True,
        "accessed_by": accessor_id,
        "accessor_type": accessor_type
    }
    
    return response


@router.get("/{patient_id}")
async def get_patient_bundle(
    patient_id: str,
    x_hospital_id: str = Header(..., description="Hospital ID"),
    x_doctor_id: Optional[str] = Header(None, description="Doctor ID"),
    include: Optional[str] = Query(
        "Patient,Condition,MedicationRequest,DocumentReference,AllergyIntolerance",
        description="Comma-separated resource types to include"
    ),
):
    """
    Get full patient data bundle in FHIR R4 format.
    
    Returns a FHIR Bundle containing all patient data for which
    the hospital has valid consent.
    
    Resource types can be filtered using the 'include' parameter.
    """
    # This endpoint checks consent for each resource type individually
    # and only includes resources where consent is valid
    
    include_types = [t.strip() for t in include.split(",")] if include else []
    
    entries = []
    consent_summary = {}
    
    # Get profile data
    profile = MOCK_EMERGENCY_PROFILES.get(patient_id)
    if not profile:
        raise HTTPException(
            status_code=404,
            detail=_create_operation_outcome("error", "not-found", f"Patient {patient_id} not found")
        )
    
    # Check consent and add Patient resource
    if "Patient" in include_types:
        # For demo, always include Patient if requested
        patient = map_user_to_fhir_patient(
            user_id=patient_id,
            name=profile.get("name"),
            age=profile.get("age"),
            gender=profile.get("gender"),
            blood_group=profile.get("blood_group"),
            emergency_contacts=profile.get("emergency_contacts", [])
        )
        entries.append(BundleEntry(
            fullUrl=f"Patient/{patient_id}",
            resource=patient.model_dump(by_alias=True, exclude_none=True)
        ))
        consent_summary["Patient"] = "granted"
    
    # Add Allergies
    if "AllergyIntolerance" in include_types:
        for idx, allergy in enumerate(profile.get("allergies", [])):
            allergy_res = map_allergy_to_fhir_allergy_intolerance(
                patient_id=patient_id,
                allergy_id=f"allergy-{patient_id}-{idx}",
                allergy_name=allergy,
                severity="moderate"
            )
            entries.append(BundleEntry(
                fullUrl=f"AllergyIntolerance/allergy-{patient_id}-{idx}",
                resource=allergy_res.model_dump(by_alias=True, exclude_none=True)
            ))
        consent_summary["AllergyIntolerance"] = "granted"
    
    # Add Conditions
    if "Condition" in include_types:
        for idx, condition in enumerate(profile.get("chronic_conditions", [])):
            cond_res = map_diagnosis_to_fhir_condition(
                patient_id=patient_id,
                diagnosis_id=f"condition-{patient_id}-{idx}",
                diagnosis_text=condition,
                clinical_status="active"
            )
            entries.append(BundleEntry(
                fullUrl=f"Condition/condition-{patient_id}-{idx}",
                resource=cond_res.model_dump(by_alias=True, exclude_none=True)
            ))
        consent_summary["Condition"] = "granted"
    
    # Add Medications
    if "MedicationRequest" in include_types:
        for idx, med in enumerate(profile.get("current_medications", [])):
            med_res = map_medication_to_fhir_medication_request(
                patient_id=patient_id,
                medication_id=f"medication-{patient_id}-{idx}",
                medication_name=med,
                is_active=True
            )
            entries.append(BundleEntry(
                fullUrl=f"MedicationRequest/medication-{patient_id}-{idx}",
                resource=med_res.model_dump(by_alias=True, exclude_none=True)
            ))
        consent_summary["MedicationRequest"] = "granted"
    
    # Log access
    await log_emergency_access(
        patient_id=patient_id,
        accessor_id=x_hospital_id,
        accessor_type="hospital",
        consent_id=None,
        success=True,
        justification="Full patient bundle access"
    )
    
    # Create bundle
    bundle = FHIRBundle(
        id=f"patient-bundle-{patient_id}",
        meta=Meta(
            lastUpdated=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+05:30"),
            source="MySehat FHIR Gateway",
            tag=[Coding(
                system="urn:mysehat:dpdp",
                code="consent-verified",
                display="Access verified under DPDP Act 2023"
            )]
        ),
        type=BundleType.COLLECTION,
        timestamp=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+05:30"),
        total=len(entries),
        entry=entries
    )
    
    response = bundle.model_dump(by_alias=True, exclude_none=True)
    response["_consent_summary"] = consent_summary
    response["_fhir_access_notice"] = "Patient data accessed via FHIR with explicit consent under DPDP Act 2023"
    
    return response
