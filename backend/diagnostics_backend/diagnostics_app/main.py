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
    print("⚠️ DPDP module not available - running without privacy compliance")


# Auto-create all tables on startup (Render-safe, no Alembic)
@app.on_event("startup")
def init_db():
    Base.metadata.create_all(bind=engine)

app = FastAPI(
    title=settings.PROJECT_NAME + " - DPDP Compliant",
    description="""
    AI-powered symptom checker with DPDP Act 2023 compliance.
    
    **Privacy Features:**
    - Clear AI disclaimers
    - Audit logging of all queries
    - Data not used for training
    - User consent verification
    """,
    openapi_url=f"{settings.API_V1_STR}/openapi.json"
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
