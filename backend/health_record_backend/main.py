"""
Health Record Backend - Main Application
DPDP Act 2023 Compliant medical document analysis service
"""
import sys
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Add current directory to path for relative imports
current_dir = Path(__file__).parent
parent_dir = current_dir.parent
if str(current_dir) not in sys.path:
    sys.path.insert(0, str(current_dir))
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

# Use consistent imports from current package
from core.config import settings
from core.db import Base, engine
from routes.health_records import router as health_records_router

# Import models to register them
from models.health_record import (
    HealthRecord, 
    ExtractedMedication, 
    ExtractedTestResult,
    CriticalHealthInfo,
    ConsentLog
)

# DPDP Compliance imports
try:
    from shared.dpdp import (
        AuditLogger, get_audit_logger,
        ConsentEngine, get_consent_engine,
        AIGovernance, get_ai_governance,
        # NEW: Global middleware and API routers for DPDP compliance
        add_dpdp_middleware, create_consent_router, create_user_rights_router, create_audit_router
    )
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("⚠️ DPDP module not available - running without central privacy compliance")

# Create tables on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME + " - DPDP Compliant",
    description="""
    **DPDP Act 2023 Compliant** Health Record Service for MySehat App.
    
    ## Features
    - Medical document OCR and analysis with AI
    - Structured data extraction (medications, tests, diagnoses)
    - Consent-aware storage with purpose-bound metadata
    - Emergency-safe data extraction (minimal data for SOS)
    - Timeline view and search
    - Auto-delete for temporary storage
    
    ## DPDP Compliance
    - **Consent-based storage**: Documents stored only with explicit consent
    - **Storage options**: Permanent, Temporary (auto-delete), View-only
    - **Right to Access**: Export all your health records
    - **Right to Erasure**: Delete all records at any time
    - **AI Transparency**: Clear disclaimers on AI-extracted data
    - **Audit Trail**: All access is logged
    
    ## Privacy Notice
    All extracted data is stored under user's control.
    This service respects patient consent, data minimization, and explainability principles.
    """,
    version="1.1.0",
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
)

# Store DPDP status in app state
app.state.dpdp_available = DPDP_AVAILABLE
if DPDP_AVAILABLE:
    app.state.audit_logger = get_audit_logger("health_record_backend")
    app.state.consent_engine = get_consent_engine()
    app.state.ai_governance = get_ai_governance("health_record_backend")
    
    # Add DPDP global middleware for consent enforcement (port 8004)
    add_dpdp_middleware(app, service_port=8004)
    
    # Add consent management and user rights API routers
    app.include_router(create_consent_router("health_record_backend"), prefix=settings.API_V1_STR, tags=["DPDP Consent"])
    app.include_router(create_user_rights_router("health_record_backend"), prefix=settings.API_V1_STR, tags=["DPDP User Rights"])
    app.include_router(create_audit_router("health_record_backend"), prefix=settings.API_V1_STR, tags=["DPDP Audit"])

# Set CORS
if settings.APP_ENV == "development":
    allow_origins = ["*"]
else:
    allow_origins = []

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health_records_router, prefix=settings.API_V1_STR)


@app.get("/")
def root():
    return {
        "message": "Welcome to MySehat Health Record Service",
        "compliance": "DPDP Act 2023 Compliant",
        "dpdp_available": DPDP_AVAILABLE,
        "disclaimer": "This service extracts information from uploaded documents using AI. It is not a medical diagnosis tool and should be verified by a healthcare professional.",
        "user_rights": {
            "access": "GET /api/v1/records/my-data/{user_id}",
            "delete": "DELETE /api/v1/records/my-data/{user_id}",
            "consent": "POST /api/v1/records/consent"
        }
    }


@app.get("/health")
def health_check():
    return {
        "status": "healthy", 
        "service": "health-record-backend",
        "dpdp_compliant": DPDP_AVAILABLE
    }
