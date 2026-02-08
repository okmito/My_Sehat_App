"""
Medicine Reminder Backend - DPDP Act 2023 Compliant
====================================================

Medication management with privacy controls.
"""

import sys
from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
import os

# Add parent directory to path for relative imports
parent_dir = Path(__file__).parent.parent.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

try:
    from medicine_backend.medicine_app.core.config import settings
    from medicine_backend.medicine_app.core.db import engine, Base
    from medicine_backend.medicine_app.routes import medications, reminders, prescriptions, user_data
except ImportError:
    from core.config import settings
    from core.db import engine, Base
    from routes import medications, reminders, prescriptions, user_data

# DPDP Compliance imports
try:
    from shared.dpdp import (
        AuditLogger, get_audit_logger,
        ConsentEngine, get_consent_engine,
        add_dpdp_middleware, create_consent_router, create_user_rights_router, create_audit_router
    )
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("⚠️ DPDP module not available - running without privacy compliance")

app = FastAPI(
    title=settings.PROJECT_NAME + " - DPDP Compliant",
    description="""
    Medication reminder and tracking service.
    
    **DPDP Compliance:**
    - Medication data under user control
    - Emergency access limited to current medications only
    - Full data export and deletion supported
    """
)

# Auto-create all tables on startup (Render-safe, no Alembic)
@app.on_event("startup")
def init_db():
    # Ensure all medicine models are imported and registered with `Base`
    try:
        from medicine_backend.medicine_app.models import Medication, MedicationSchedule, Prescription, DoseEvent  # noqa: F401
    except Exception:
        # Fallback to local package import style
        from models import Medication, MedicationSchedule, Prescription, DoseEvent  # noqa: F401

    # Create tables for all registered models
    Base.metadata.create_all(bind=engine)

# Add DPDP Middleware and Consent APIs
if DPDP_AVAILABLE:
    # Add middleware (Port 8002 = Medicine)
    add_dpdp_middleware(app, service_port=8002)
    
    # Add consent management APIs
    app.include_router(create_consent_router("medicine_backend"), prefix="/api/v1")
    app.include_router(create_user_rights_router("medicine_backend"), prefix="/api/v1")
    app.include_router(create_audit_router("medicine_backend"), prefix="/api/v1")

# Store DPDP status in app state
app.state.dpdp_available = DPDP_AVAILABLE
if DPDP_AVAILABLE:
    app.state.audit_logger = get_audit_logger("medicine_backend")
    app.state.consent_engine = get_consent_engine()

# Mount uploads directory for static access
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Include routers
app.include_router(medications.router)
app.include_router(reminders.router)
app.include_router(prescriptions.router)
app.include_router(user_data.router)  # DPDP User Rights

@app.get("/health")
def health():
    return {
        "status": "ok",
        "dpdp_compliant": DPDP_AVAILABLE
    }

@app.get("/")
def root():
    return {
        "message": "Medicine Reminder Backend",
        "dpdp_compliant": DPDP_AVAILABLE,
        "notice": "Your medication data is protected under DPDP Act 2023"
    }
