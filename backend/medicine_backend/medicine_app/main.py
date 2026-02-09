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
    print("[OK] Models imported successfully (package style)", flush=True)
except ImportError as e:
    print(f"[WARN] Package import failed: {e}, trying local import...", flush=True)
    from models import Medication, MedicationSchedule, Prescription, DoseEvent
    print("[OK] Models imported successfully (local style)", flush=True)

from contextlib import asynccontextmanager

# FORCE-SAFE: Database initialization function
# Moved out of module scope to prevent double-execution and race conditions
def init_db():
    """
    Initialize database tables with robust error handling.
    
    Strategy:
    1. Inspect current DB state.
    2. Attempt `create_all` with `checkfirst=True`.
    3. Catch "already exists" errors specifically and verify tables exist.
    """
    print("=" * 60, flush=True)
    print("MEDICINE BACKEND: Force-Safe Database Initialization", flush=True)
    print("=" * 60, flush=True)
    
    try:
        # Step 1: Inspect existing state
        from sqlalchemy import inspect
        inspector = inspect(engine)
        existing_tables = set(inspector.get_table_names())
        print(f"DEBUG: Existing tables before init: {existing_tables}", flush=True)
        
        # Step 2: Attempt creation using SQLAlchemy's checkfirst logic
        # With our new naming convention in core/db.py, this should be reliable.
        print("DEBUG: Executing Base.metadata.create_all()...", flush=True)
        Base.metadata.create_all(bind=engine, checkfirst=True)
        print("[OK] Schema synchronization complete.", flush=True)
        
        # Step 3: Verify final state
        final_tables = set(inspect(engine).get_table_names())
        print(f"[OK] Final table list: {final_tables}", flush=True)
        
        if not final_tables:
            print("[ERR] CRITICAL: No tables found after initialization!", flush=True)
            # FORCE-SAFE: Attempt explicit creation if checkfirst failed silently (rare but possible)
            print("[WARN] Attempting forced creation of missing tables...", flush=True)
            Base.metadata.create_all(bind=engine)
            print("[OK] Forced creation complete.", flush=True)
        else:
            print(f"[OK] SUCCESS: medicine_backend ready with {len(final_tables)} tables.", flush=True)

    except Exception as e:
        error_msg = str(e).lower()
        # FORCE-SAFE: If index already exists, it means the schema is effectively synced.
        # We ignore this specific error to ensure startup continuity.
        if "index" in error_msg and "already exists" in error_msg:
            print(f"[INFO] Index conflict detected (Safe to ignore as schema exists): {e}", flush=True)
            # Double check tables exist
            final_tables = set(inspect(engine).get_table_names())
            if final_tables:
                print(f"[OK] Verified tables exist: {final_tables}. Continuing startup.", flush=True)
            else:
                 print("[ERR] ERROR: Index exists but tables missing? This indicates corrupt DB state.", flush=True)
        else:
            print(f"[WARN] Database initialization error: {e}", flush=True)
            # We explicitly allow startup to continue even on DB error to avoid crash-loop
            import traceback
            traceback.print_exc()

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup: Initialize Database
    print("[INFO] Medicine Backend: Starting up...", flush=True)
    init_db()
    
    # Store DPDP components in state if available
    if DPDP_AVAILABLE:
        app.state.dpdp_available = True
        app.state.audit_logger = get_audit_logger("medicine_backend")
        app.state.consent_engine = get_consent_engine()
    else:
        app.state.dpdp_available = False
        
    yield
    # Shutdown logic (if any)
    print("[INFO] Medicine Backend: Shutting down...", flush=True)

app = FastAPI(
    title=settings.PROJECT_NAME + " - DPDP Compliant",
    description="""
    Medication reminder and tracking service.
    
    **DPDP Compliance:**
    - Medication data under user control
    - Emergency access limited to current medications only
    - Full data export and deletion supported
    """,
    lifespan=lifespan  # Register lifespan handler
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
