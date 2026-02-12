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
from health_record_backend.core.config import settings
from health_record_backend.core.db import Base, engine
from health_record_backend.routes.health_records import router as health_records_router

# Import models to register them
from health_record_backend.models.health_record import (
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
    print("[WARN] DPDP module not available - running without central privacy compliance")

from contextlib import asynccontextmanager

# Database initialization function
def init_db():
    """Initialize database tables on startup."""
    print("[INFO] Initializing Health Records Backend database...")
    try:
        Base.metadata.create_all(bind=engine)
        print(f"[OK] Health Records database tables created successfully")
        
        # List all tables
        from sqlalchemy import inspect
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        print(f"[OK] Available Health Records tables: {', '.join(tables)}")
    except Exception as e:
        print(f"[ERROR] Failed to create Health Records database tables: {e}")
        raise

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
    yield
    # Shutdown
    pass

app = FastAPI(
    title="Health Records Backend - DPDP Compliant",
    description="""
    Medical record management and storage.
    
    **DPDP Compliance:**
    - Health records under user control
    - Emergency access with audit trail
    - Full data export and deletion supported
    """,
    lifespan=lifespan
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
