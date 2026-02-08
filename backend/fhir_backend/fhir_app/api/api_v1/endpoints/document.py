"""
FHIR DocumentReference Endpoint
================================

GET /fhir/DocumentReference?patient={id} - Get documents in FHIR format

All access requires valid DPDP consent and is audit logged.
"""

from fastapi import APIRouter, HTTPException, Header, Query
from typing import Optional
from datetime import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent.parent))

from fhir_backend.fhir_app.models import (
    FHIRDocumentReference, FHIRDiagnosticReport, FHIRBundle,
    FHIROperationOutcome, OperationOutcomeIssue, BundleEntry, BundleType
)
from fhir_backend.fhir_app.core import (
    map_document_to_fhir_document_reference,
    map_lab_report_to_fhir_diagnostic_report
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
            data_categories=["documents", "health_records"],
            service_name="fhir_backend",
            success=success,
            error_message=reason if not success else None
        )
    except Exception as e:
        print(f"[FHIR Audit] Log failed: {e}")


# Mock document data
MOCK_DOCUMENTS = {
    "patient-001": [
        {
            "document_id": "doc-001",
            "document_type": "lab_report",
            "document_date": datetime(2024, 1, 15, 10, 0, 0),
            "doctor_name": "Dr. Sunita Rao",
            "hospital_name": "City Diagnostic Center",
            "diagnosis": "HbA1c: 6.8% - Good diabetic control",
            "description": "Blood Test Report - Diabetes Panel",
            "test_results": [
                {"test_name": "HbA1c", "result_value": "6.8", "unit": "%", "reference_range": "< 6.5", "is_abnormal": True},
                {"test_name": "Fasting Glucose", "result_value": "125", "unit": "mg/dL", "reference_range": "70-100", "is_abnormal": True}
            ],
            "confidence_score": 0.95
        },
        {
            "document_id": "doc-002",
            "document_type": "radiology",
            "document_date": datetime(2023, 12, 20, 14, 30, 0),
            "doctor_name": "Dr. Radiology Specialist",
            "hospital_name": "Metro Imaging Center",
            "diagnosis": "ECG shows normal sinus rhythm",
            "description": "ECG Report",
            "test_results": [],
            "confidence_score": 0.92
        },
        {
            "document_id": "doc-003",
            "document_type": "prescription",
            "document_date": datetime(2024, 1, 10, 11, 0, 0),
            "doctor_name": "Dr. Anil Mehta",
            "hospital_name": "Apollo Hospital",
            "diagnosis": "Type 2 Diabetes, Hypertension",
            "description": "Prescription - Monthly Follow-up",
            "test_results": [],
            "confidence_score": 0.88
        }
    ],
    "patient-002": [
        {
            "document_id": "doc-004",
            "document_type": "lab_report",
            "document_date": datetime(2024, 2, 1, 9, 0, 0),
            "doctor_name": "Dr. Cardiac Lab",
            "hospital_name": "Heart Care Institute",
            "diagnosis": "Elevated cardiac markers - continue monitoring",
            "description": "Cardiac Enzyme Panel",
            "test_results": [
                {"test_name": "Troponin I", "result_value": "0.08", "unit": "ng/mL", "reference_range": "< 0.04", "is_abnormal": True},
                {"test_name": "CK-MB", "result_value": "28", "unit": "U/L", "reference_range": "5-25", "is_abnormal": True}
            ],
            "confidence_score": 0.97
        }
    ]
}


@router.get("")
async def search_document_references(
    patient: str = Query(..., description="Patient ID"),
    type: Optional[str] = Query(None, description="Document type filter"),
    _count: Optional[int] = Query(100, description="Maximum results"),
    x_hospital_id: str = Header(..., description="Hospital ID"),
    x_doctor_id: Optional[str] = Header(None, description="Doctor ID"),
):
    """
    Search document references for a patient in FHIR R4 format.
    
    Returns a FHIR Bundle containing DocumentReference resources.
    Requires valid DPDP consent for document/health record data.
    """
    # Verify consent
    is_valid, consent_id, reason = await verify_consent(patient, x_hospital_id)
    
    if not is_valid:
        await log_access(patient, x_hospital_id, "DocumentReference", consent_id, False, reason)
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome(
                "error", "forbidden",
                f"Access denied: {reason or 'No consent for document/health record data'}"
            )
        )
    
    # Get document data
    documents = MOCK_DOCUMENTS.get(patient, [])
    
    # Apply type filter if provided
    if type:
        documents = [d for d in documents if d.get("document_type", "").lower() == type.lower()]
    
    # Map to FHIR DocumentReferences
    entries = []
    for doc in documents[:_count]:
        doc_ref = map_document_to_fhir_document_reference(
            patient_id=patient,
            **{k: v for k, v in doc.items() if k != "test_results" and k != "confidence_score"}
        )
        entries.append(BundleEntry(
            fullUrl=f"urn:uuid:{doc_ref.id}",
            resource=doc_ref.model_dump(by_alias=True, exclude_none=True)
        ))
    
    # Log access
    await log_access(patient, x_hospital_id, "DocumentReference", consent_id, True)
    
    # Return as FHIR Bundle
    bundle = FHIRBundle(
        id=f"documents-{patient}",
        type=BundleType.SEARCHSET,
        total=len(entries),
        timestamp=datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%S+05:30"),
        entry=entries
    )
    
    return bundle.model_dump(by_alias=True, exclude_none=True)


@router.get("/{document_id}")
async def get_document_reference(
    document_id: str,
    x_hospital_id: str = Header(..., description="Hospital ID"),
    x_patient_id: str = Header(..., description="Patient ID for consent check"),
):
    """Get a specific document reference by ID"""
    is_valid, consent_id, reason = await verify_consent(x_patient_id, x_hospital_id)
    
    if not is_valid:
        await log_access(x_patient_id, x_hospital_id, "DocumentReference", consent_id, False, reason)
        raise HTTPException(
            status_code=403,
            detail=_create_operation_outcome("error", "forbidden", f"Access denied: {reason}")
        )
    
    # Search for document
    for patient_id, documents in MOCK_DOCUMENTS.items():
        for doc in documents:
            if doc["document_id"] == document_id:
                doc_ref = map_document_to_fhir_document_reference(
                    patient_id=patient_id,
                    **{k: v for k, v in doc.items() if k != "test_results" and k != "confidence_score"}
                )
                await log_access(x_patient_id, x_hospital_id, "DocumentReference", consent_id, True)
                return doc_ref.model_dump(by_alias=True, exclude_none=True)
    
    raise HTTPException(
        status_code=404,
        detail=_create_operation_outcome("error", "not-found", f"DocumentReference {document_id} not found")
    )
