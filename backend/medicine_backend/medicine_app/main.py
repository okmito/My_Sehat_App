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

# CRITICAL: Import all models at module level so they register with Base.metadata
# This MUST happen before init_db() is called
print("=" * 60, flush=True)
print("MEDICINE BACKEND: Importing models at module level", flush=True)
print("=" * 60, flush=True)
try:
    from medicine_backend.medicine_app.models import Medication, MedicationSchedule, Prescription, DoseEvent
    print("✓ Models imported successfully (package style)", flush=True)
except ImportError as e:
    print(f"⚠️  Package import failed: {e}, trying local import...", flush=True)
    from models import Medication, MedicationSchedule, Prescription, DoseEvent
    print("✓ Models imported successfully (local style)", flush=True)

# Database initialization function
def init_db():
    """Initialize database tables on startup."""
    print("🔧 Initializing Medicine Backend database...", flush=True)
    
    # Debug: Check what's in Base.metadata
    print(f"DEBUG: Base class: {Base}", flush=True)
    print(f"DEBUG: Base.metadata: {Base.metadata}", flush=True)
    print(f"DEBUG: Base.metadata.tables keys: {list(Base.metadata.tables.keys())}", flush=True)
    
    # Try to access the model classes to ensure they're loaded
    print(f"DEBUG: Medication class: {Medication}", flush=True)
    print(f"DEBUG: Medication.__tablename__: {Medication.__tablename__}", flush=True)
    print(f"DEBUG: Medication.__table__: {Medication.__table__}", flush=True)
    
    # Create tables for all registered models
    try:
        print(f"DEBUG: Calling Base.metadata.create_all(bind=engine)...", flush=True)
        try:
            Base.metadata.create_all(bind=engine)
        except Exception as create_err:
            # Handle "already exists" errors gracefully (like DPDP modules)
            if "already exists" in str(create_err).lower():
                print(f"⚠️  Tables/indexes already exist (this is OK): {create_err}", flush=True)
            else:
                raise
        
        print(f"✓ Database tables created successfully at: {settings.DATABASE_URL}", flush=True)
        
        # List all tables that were created
        from sqlalchemy import inspect
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        print(f"✓ Available tables in database: {', '.join(tables) if tables else 'NONE'}", flush=True)
        
        if not tables:
            print("❌ WARNING: No tables were created! Models may not be registered.", flush=True)
            print(f"DEBUG: Checking Base.metadata.sorted_tables: {Base.metadata.sorted_tables}", flush=True)
        else:
            print(f"✅ SUCCESS: {len(tables)} tables are ready!", flush=True)
    except Exception as e:
        print(f"❌ Failed to create database tables: {e}", flush=True)
        import traceback
        traceback.print_exc()
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
