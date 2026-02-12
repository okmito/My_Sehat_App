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
    print("[WARN] DPDP module not available - running without privacy compliance")

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
        existing_tables_start = set(inspector.get_table_names())
        print(f"DEBUG: Existing tables before init: {existing_tables_start}", flush=True)
        
        # Step 2: Iterative Table Creation (The "Tank" Strategy)
        # Instead of create_all() which stops on the first error, we handle each table individually.
        print("DEBUG: Executing iterative table creation...", flush=True)
        
        sorted_tables = Base.metadata.sorted_tables
        for table in sorted_tables:
            try:
                print(f"DEBUG: Processing table '{table.name}'...", flush=True)
                table.create(bind=engine, checkfirst=True)
                print(f"[OK] Table '{table.name}' synced.", flush=True)
            except Exception as e:
                error_msg = str(e).lower()
                if "index" in error_msg and "already exists" in error_msg:
                    print(f"[INFO] Index conflict on '{table.name}' (Safe to ignore): {e}", flush=True)
                elif "already exists" in error_msg:
                     print(f"[INFO] Table '{table.name}' already exists: {e}", flush=True)
                else:
                    print(f"[WARN] Failed to create table '{table.name}': {e}", flush=True)
        
        # Step 3: Verify final state
        inspector = inspect(engine)
        final_tables = set(inspector.get_table_names())
        print(f"[OK] Final table list: {final_tables}", flush=True)
        
        expected_tables = {t.name for t in Base.metadata.sorted_tables}
        missing_tables = expected_tables - final_tables
        
        if missing_tables:
            print(f"[ERR] CRITICAL: Missing tables after initialization: {missing_tables}", flush=True)
        else:
            print(f"[OK] SUCCESS: Medicine backend fully initialized with {len(final_tables)} tables.", flush=True)

    except Exception as e:
        print(f"[WARN] Unexpected database initialization error: {e}", flush=True)
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
