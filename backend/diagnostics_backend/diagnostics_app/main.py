"""
Diagnostics Backend - DPDP Act 2023 Compliant
==============================================

Provides symptom checking with AI governance and privacy controls.
"""

import sys
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Add parent directory to path for relative imports
parent_dir = Path(__file__).parent.parent.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

try:
    from diagnostics_backend.diagnostics_app.core.config import settings
    from diagnostics_backend.diagnostics_app.api.api_v1.api import api_router
    from diagnostics_backend.diagnostics_app.db.base import Base
    from diagnostics_backend.diagnostics_app.db.session import engine
except ImportError:
    from core.config import settings
    from api.api_v1.api import api_router
    from db.base import Base
    from db.session import engine

# DPDP Compliance imports
try:
    from shared.dpdp import (
        AuditLogger, get_audit_logger, AIGovernance, get_ai_governance,
        add_dpdp_middleware, create_consent_router, create_user_rights_router, create_audit_router
    )
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("[WARN] DPDP module not available - running without privacy compliance")
from contextlib import asynccontextmanager

# Database initialization function
# CRITICAL: Import all models at module level so they register with Base.metadata
# This MUST happen before init_db() is called
# CRITICAL: Import all models at module level so they register with Base.metadata
# This MUST happen before init_db() is called
# Enforce package imports to match services/session_service.py and prevent "Multiple classes found"
try:
    from diagnostics_backend.diagnostics_app.db.models import TriageSession, TriageMessage, TriageObservation, MediaAsset, TriageOutput
    print("[OK] Models imported successfully (package style)", flush=True)
except ImportError as e:
    print(f"[ERR] Failed to import models via package path: {e}", flush=True)
    # Raising error here is better than falling back and causing confusing registry errors later
    raise

# Database initialization function
def init_db():
    """Initialize database tables with robust error handling (Iterative Strategy)."""
    print("[INFO] Initializing Diagnostics Backend database...", flush=True)
    try:
        # Step 1: Inspect existing state
        from sqlalchemy import inspect
        inspector = inspect(engine)
        existing_tables_start = set(inspector.get_table_names())
        print(f"DEBUG: Existing tables before init: {existing_tables_start}", flush=True)

        # Step 2: Iterative Table Creation (The "Tank" Strategy)
        sorted_tables = Base.metadata.sorted_tables
        for table in sorted_tables:
            try:
                print(f"DEBUG: Processing table '{table.name}'...", flush=True)
                table.create(bind=engine, checkfirst=True)
                print(f"[OK] Table '{table.name}' synced.", flush=True)
            except Exception as e:
                error_msg = str(e).lower()
                if "index" in error_msg and "already exists" in error_msg:
                    print(f"[INFO] Index conflict on '{table.name}' (Safe to ignore).", flush=True)
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
             print(f"[OK] SUCCESS: Diagnostics backend fully initialized with {len(final_tables)} tables.", flush=True)

    except Exception as e:
        print(f"[WARN] Unexpected database initialization error: {e}", flush=True)
        import traceback
        traceback.print_exc()

# Lifespan context manager
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    init_db()
    yield
    # Shutdown
    pass

app = FastAPI(
    title=settings.PROJECT_NAME + " - DPDP Compliant",
    description="""
    AI-powered diagnostic triage and symptom analysis.
    
    **DPDP Compliance:**
    - Diagnostic data under user control
    - AI processing with explicit consent
    - Full data export and deletion supported
    """,
    lifespan=lifespan
)

# Add DPDP Middleware and Consent APIs
if DPDP_AVAILABLE:
    # Add middleware (Port 8001 = Diagnostics)
    add_dpdp_middleware(app, service_port=8001)
    
    # Add consent management APIs
    app.include_router(create_consent_router("diagnostics_backend"), prefix="/api/v1")
    app.include_router(create_user_rights_router("diagnostics_backend"), prefix="/api/v1")
    app.include_router(create_audit_router("diagnostics_backend"), prefix="/api/v1")

# Store DPDP status in app state
app.state.dpdp_available = DPDP_AVAILABLE
if DPDP_AVAILABLE:
    app.state.audit_logger = get_audit_logger("diagnostics_backend")
    app.state.ai_governance = get_ai_governance("diagnostics_backend")

# Set all CORS enabled origins
if settings.APP_ENV == "development":
    allow_origins = ["*"]
else:
    allow_origins = [] # Update with production origins

app.add_middleware(
    CORSMiddleware,
    allow_origins=allow_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix=settings.API_V1_STR)

@app.get("/")
def root():
    return {
        "message": "Welcome to MySehat Diagnostics Backend",
        "dpdp_compliant": DPDP_AVAILABLE,
        "ai_disclaimer": "⚠️ This is an AI-powered symptom checker. It provides general health information only and is NOT a medical diagnosis. Always consult a healthcare professional."
    }

@app.get("/health")
def health_check():
    return {
        "status": "ok",
        "dpdp_compliant": DPDP_AVAILABLE
    }
