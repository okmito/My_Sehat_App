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
from contextlib import asynccontextmanager

# Database initialization function
def init_db():
    """Initialize database tables on startup."""
    print("🔧 Initializing Medicine Backend database...", flush=True)
    
    # Ensure all medicine models are imported and registered with `Base`
    try:
        from medicine_backend.medicine_app.models import Medication, MedicationSchedule, Prescription, DoseEvent  # noqa: F401
        print("✓ Models imported successfully (package style)", flush=True)
    except Exception as e:
        print(f"⚠️  Package import failed: {e}, trying local import...", flush=True)
        try:
            # Fallback to local package import style
            from models import Medication, MedicationSchedule, Prescription, DoseEvent  # noqa: F401
            print("✓ Models imported successfully (local style)", flush=True)
        except Exception as e2:
            print(f"❌ Failed to import models: {e2}", flush=True)
            raise

    # Create tables for all registered models
    try:
        Base.metadata.create_all(bind=engine)
        print(f"✓ Database tables created successfully at: {settings.DATABASE_URL}", flush=True)
        
        # List all tables that were created
        from sqlalchemy import inspect
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        print(f"✓ Available tables: {', '.join(tables)}", flush=True)
    except Exception as e:
        print(f"❌ Failed to create database tables: {e}", flush=True)
        raise

# Initialize database immediately at module import time
# This ensures tables are created when uvicorn loads the module
print("=" * 60, flush=True)
print("MEDICINE BACKEND: Initializing at module import time", flush=True)
print("=" * 60, flush=True)
init_db()
print("=" * 60, flush=True)
print("MEDICINE BACKEND: Database initialization complete", flush=True)
print("=" * 60, flush=True)

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

@app.post("/admin/init-db")
def manual_init_db():
    """Manual database initialization endpoint - call this if tables aren't created"""
    try:
        init_db()
        return {"status": "success", "message": "Database tables created successfully"}
    except Exception as e:
        return {"status": "error", "message": str(e)}

@app.get("/")
def root():
    return {
        "message": "Medicine Reminder Backend",
        "dpdp_compliant": DPDP_AVAILABLE,
        "notice": "Your medication data is protected under DPDP Act 2023"
    }
