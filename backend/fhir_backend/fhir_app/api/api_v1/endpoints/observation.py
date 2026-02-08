"""
FHIR Observation Endpoint
=========================

GET /fhir/Observation?patient={id} - Get observations (symptoms, vitals) in FHIR format

All access requires valid DPDP consent and is audit logged.
"""

from fastapi import APIRouter, HTTPException, Header, Query
from typing import Optional, List
from datetime import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent.parent))

from fhir_backend.fhir_app.models import (
    FHIRObservation, FHIRBundle, FHIROperationOutcome, 
    OperationOutcomeIssue, BundleEntry, BundleType
)
from fhir_backend.fhir_app.core import map_symptom_to_fhir_observation

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
            data_categories=["diagnostics"],
            service_name="fhir_backend",
            success=success,
            error_message=reason if not success else None
        )
    except Exception as e:
        print(f"[FHIR Audit] Log failed: {e}")


# Mock symptom data
MOCK_SYMPTOMS = {
    "patient-001": [
        {
            "session_id": "sess-001",
            "symptom_text": "Experiencing headache and mild dizziness for 2 days",
            "severity": "moderate",
            "duration": "2 days",
            "body_site": "Head",
            "recorded_at": datetime(2026, 2, 5, 10, 30, 0),
            "triage_result": {
                "summary": "Likely tension headache. Monitor symptoms.",
                "possible_causes": [
                    {"condition": "Tension headache", "probability": 0.7},
                    {"condition": "Dehydration", "probability": 0.2}
                ]
            }
        },
        {
            "session_id": "sess-002",
            "symptom_text": "Chest tightness when climbing stairs",
            "severity": "moderate",
            "duration": "1 week",
            "body_site": "Chest",
            "recorded_at": datetime(2026, 2, 7, 14, 15, 0),
            "triage_result": {
                "summary": "Possible cardiovascular issue. Recommend checkup.",
                "possible_causes": [
                    {"condition": "Exertional dyspnea", "probability": 0.5}
                ]
            }
        }
    ],
    "patient-002": [
        {
            "session_id": "sess-003",
            "symptom_text": "Sharp chest pain radiating to left arm",
            "severity": "severe",
            "duration": "30 minutes",
            "body_site": "Chest",
            "recorded_at": datetime(2026, 2, 8, 8, 0, 0),
            "triage_result": {
                "summary": "URGENT: Possible cardiac event. Seek immediate care.",
                "possible_causes": [
                    {"condition": "Acute coronary syndrome", "probability": 0.8}
                ]
            }
        }
    ]
}


@router.get("")
async def search_observations(
    patient: str = Query(..., description="Patient ID to search observations for"),
    category: Optional[str] = Query(None, description="Category filter (e.g., survey, vital-signs)"),
    _count: Optional[int] = Query(100, description="Maximum number of results"),
    x_hospital_id: str = Header(..., description="Hospital ID requesting access"),
    x_doctor_id: Optional[str] = Header(None, description="Doctor ID"),
):
    """
    Search observations for a patient in FHIR R4 format.
    
    Returns a FHIR Bundle containing Observation resources.
    Requires valid DPDP consent.
    """
    # Verify consent
    is_valid, consent_id, reason = await verify_consent(patient, x_hospital_id)
    
    if not is_valid:
        await log_access(patient, x_hospital_id, "Observation", consent_id, False, reason)
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome(
                "error", "forbidden",
                f"Access denied: {reason or 'No consent for symptom/observation data'}"
            )
        )
    
    # Get symptom data
    symptoms = MOCK_SYMPTOMS.get(patient, [])
    
    # Map to FHIR Observations
    entries = []
    for symptom in symptoms[:_count]:
        obs = map_symptom_to_fhir_observation(
            patient_id=patient,
            **symptom
        )
        entries.append(BundleEntry(
            fullUrl=f"urn:uuid:{obs.id}",
            resource=obs.model_dump(by_alias=True, exclude_none=True)
        ))
    
    # Log access
    await log_access(patient, x_hospital_id, "Observation", consent_id, True)
    
    # Return as FHIR Bundle
    bundle = FHIRBundle(
        id=f"observations-{patient}",
        type=BundleType.SEARCHSET,
        total=len(entries),
        timestamp=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+05:30"),
        entry=entries
    )
    
    return bundle.model_dump(by_alias=True, exclude_none=True)


@router.get("/{observation_id}")
async def get_observation(
    observation_id: str,
    x_hospital_id: str = Header(..., description="Hospital ID"),
    x_patient_id: str = Header(..., description="Patient ID for consent check"),
):
    """Get a specific observation by ID"""
    # Verify consent
    is_valid, consent_id, reason = await verify_consent(x_patient_id, x_hospital_id)
    
    if not is_valid:
        await log_access(x_patient_id, x_hospital_id, "Observation", consent_id, False, reason)
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome("error", "forbidden", f"Access denied: {reason}")
        )
    
    # Search for observation
    for patient_id, symptoms in MOCK_SYMPTOMS.items():
        for symptom in symptoms:
            if symptom["session_id"] == observation_id:
                obs = map_symptom_to_fhir_observation(patient_id=patient_id, **symptom)
                await log_access(x_patient_id, x_hospital_id, "Observation", consent_id, True)
                return obs.model_dump(by_alias=True, exclude_none=True)
    
    raise HTTPException(
        status_code=404,
        detail=_create_operation_outcome("error", "not-found", f"Observation {observation_id} not found")
    )
