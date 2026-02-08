"""
FHIR Backend Main Application
==============================

Standalone FHIR R4 API server with DPDP compliance.
Can be run independently or mounted as part of the gateway.
"""

from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime
import sys
from pathlib import Path

# Add parent path for imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from fhir_backend.fhir_app.api.api_v1.router import api_router

# Create FastAPI app
fhir_app = FastAPI(
    title="MySehat FHIR R4 API",
    description="""
## HL7 FHIR R4 API for MySehat Healthcare Platform

This API provides FHIR R4 compliant endpoints for healthcare interoperability.

### DPDP Compliance
All endpoints enforce consent verification under the Digital Personal Data Protection (DPDP) Act 2023.

### Available Resources
- **Patient** - Patient demographics
- **Observation** - Clinical observations (symptoms, vitals)
- **Condition** - Diagnoses and chronic conditions
- **MedicationRequest** - Prescriptions and medication orders
- **DiagnosticReport** - Lab reports and diagnostic results
- **DocumentReference** - Medical documents
- **AllergyIntolerance** - Patient allergies
- **Bundle** - Collection of resources (including emergency bundle)

### Authentication
All requests must include:
- `X-Hospital-Id`: Hospital identifier
- `X-Patient-Id`: (Optional) Patient identifier for consent verification

### Emergency Access
Emergency endpoints provide time-limited access to critical patient data during SOS situations.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    openapi_tags=[
        {"name": "FHIR Patient", "description": "Patient demographics"},
        {"name": "FHIR Observation", "description": "Clinical observations"},
        {"name": "FHIR MedicationRequest", "description": "Medication prescriptions"},
        {"name": "FHIR DocumentReference", "description": "Medical documents"},
        {"name": "FHIR Bundle", "description": "Resource collections and emergency data"},
        {"name": "FHIR Metadata", "description": "Server capabilities"},
    ]
)

# CORS Configuration
fhir_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# FHIR Content-Type middleware
@fhir_app.middleware("http")
async def add_fhir_headers(request: Request, call_next):
    """Add FHIR-specific headers to responses"""
    response = await call_next(request)
    
    # Add FHIR content type for JSON responses
    if response.headers.get("content-type", "").startswith("application/json"):
        response.headers["Content-Type"] = "application/fhir+json; charset=utf-8"
    
    # Add DPDP compliance header
    response.headers["X-DPDP-Compliant"] = "true"
    response.headers["X-FHIR-Version"] = "4.0.1"
    
    return response


# Include FHIR API router
fhir_app.include_router(api_router, prefix="")


# Root endpoint
@fhir_app.get("/", tags=["FHIR Metadata"])
async def fhir_root():
    """FHIR API root - returns server information"""
    return {
        "resourceType": "CapabilityStatement",
        "status": "active",
        "date": datetime.utcnow().isoformat(),
        "kind": "instance",
        "software": {
            "name": "MySehat FHIR Server",
            "version": "1.0.0"
        },
        "implementation": {
            "description": "MySehat FHIR R4 API with DPDP compliance",
            "url": "https://mysehat.app/fhir"
        },
        "fhirVersion": "4.0.1",
        "format": ["json"],
        "rest": [{
            "mode": "server",
            "security": {
                "cors": True,
                "service": [{
                    "coding": [{
                        "system": "http://terminology.hl7.org/CodeSystem/restful-security-service",
                        "code": "SMART-on-FHIR"
                    }]
                }],
                "description": "DPDP Act 2023 compliant. All access requires valid consent and is audit logged."
            }
        }]
    }


@fhir_app.get("/health", tags=["FHIR Metadata"])
async def fhir_health():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "fhir_version": "R4 (4.0.1)",
        "dpdp_compliant": True,
        "timestamp": datetime.utcnow().isoformat()
    }


# Run standalone
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:fhir_app",
        host="0.0.0.0",
        port=8020,
        reload=True
    )
