"""
FHIR R4 API Router
==================

Routes all FHIR endpoints with proper prefixes.
All endpoints enforce DPDP consent before data access.
"""

from fastapi import APIRouter

# Import endpoint routers
from .endpoints import patient, observation, medication, document, emergency

api_router = APIRouter()

# FHIR R4 Standard Endpoints
api_router.include_router(
    patient.router, 
    prefix="/Patient", 
    tags=["FHIR Patient"]
)
api_router.include_router(
    observation.router, 
    prefix="/Observation", 
    tags=["FHIR Observation"]
)
api_router.include_router(
    medication.router, 
    prefix="/MedicationRequest", 
    tags=["FHIR MedicationRequest"]
)
api_router.include_router(
    document.router, 
    prefix="/DocumentReference", 
    tags=["FHIR DocumentReference"]
)

# Bundle endpoints (including emergency)
api_router.include_router(
    emergency.router, 
    prefix="/Bundle", 
    tags=["FHIR Bundle"]
)

# Additional health endpoint for FHIR service
@api_router.get("/metadata", tags=["FHIR Metadata"])
async def fhir_capability_statement():
    """
    Returns FHIR CapabilityStatement (simplified).
    Describes the FHIR capabilities of this server.
    """
    return {
        "resourceType": "CapabilityStatement",
        "status": "active",
        "kind": "instance",
        "fhirVersion": "4.0.1",
        "format": ["json"],
        "rest": [{
            "mode": "server",
            "security": {
                "description": "DPDP Act 2023 compliant. All access requires valid consent."
            },
            "resource": [
                {"type": "Patient", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "Observation", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "Condition", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "MedicationRequest", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "DiagnosticReport", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "DocumentReference", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "AllergyIntolerance", "interaction": [{"code": "read"}, {"code": "search-type"}]},
                {"type": "Bundle", "interaction": [{"code": "read"}]},
            ]
        }]
    }
