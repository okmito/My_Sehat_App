"""
Gateway Application - Composes Three Independent FastAPI Backends

This gateway provides:
- ONE unified FastAPI app on ONE port
- ONE Swagger UI at /docs with all endpoints grouped by domain
- Clear API prefixes: /diagnostics, /mental-health, /medicine-reminder
- NO modifications to backend logic
- Extensible design for adding new backends
- DPDP Act 2023 Compliant consent management endpoints

Architecture:
- Diagnostics: Mounts the api_router with /triage prefix
- Mental Health: Mounts endpoints with tags for grouping
- Medicine: Mounts individual routers (medications, reminders, prescriptions)
- DPDP: Unified consent, user rights, and audit endpoints
"""

# Add parent directory to Python path for backend imports
import sys
from pathlib import Path
_parent_dir = Path(__file__).resolve().parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

from fastapi import FastAPI, APIRouter, Depends
from fastapi.middleware.cors import CORSMiddleware
from datetime import datetime, date
from typing import List, Optional

# DPDP Compliance imports for Gateway
try:
    from shared.dpdp import (
        create_consent_router, create_user_rights_router, create_audit_router
    )
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("⚠️ DPDP module not available - running without privacy compliance endpoints")

# Auth Backend imports
try:
    from auth_backend import auth_router, init_db as init_auth_db, seed_database as seed_auth_db
    AUTH_AVAILABLE = True
except ImportError as e:
    AUTH_AVAILABLE = False
    print(f"⚠️ Auth backend not available: {e}")

# ==========================================
# 1. DIAGNOSTICS BACKEND - Router Composition
# ==========================================
# Import the diagnostics endpoints router directly
from diagnostics_backend.diagnostics_app.api.api_v1.endpoints import triage

# Create a new diagnostics router with proper tagging
diagnostics_router_custom = APIRouter()
diagnostics_router_custom.include_router(triage.router, prefix="/triage", tags=["Diagnostics"])

# ==========================================
# 2. MENTAL HEALTH BACKEND - Router Wrapping
# ==========================================
# Mental health backend defines endpoints directly on app, so we create a router wrapper
from fastapi import HTTPException
from mental_health_backend.mental_health_app.models import (
    ChatRequest, ChatResponse,
    CheckinQuestionsResponse, CheckinSubmitRequest, CheckinSubmitResponse
)
from mental_health_backend.mental_health_app import db
from mental_health_backend.mental_health_app.services import ai_agent, risk_engine

mental_health_router = APIRouter(prefix="/mental-health", tags=["Mental Health"])

@mental_health_router.get("/health")
def mental_health_health():
    """Mental Health service health check"""
    return {"status": "ok"}

@mental_health_router.post("/chat/message", response_model=ChatResponse)
def mental_health_chat_message(request: ChatRequest):
    """Chat with mental health AI agent and get risk assessment"""
    # 1. Save User Message
    user_msg_id = db.save_message(request.user_id, "user", request.message)

    # 2. Get LLM Analysis
    llm_result = ai_agent.analyze_message_llm(request.message)

    # 3. Deterministic Risk Assessment
    kw_score, reasons = risk_engine.calculate_risk_score(request.message)

    # Check if deterministic engine caught self-harm (score >= 20)
    deterministic_sh = (kw_score >= 20)

    final_risk_level = risk_engine.determinize_risk_level(
        llm_result.get("risk_level", "medium"),
        kw_score,
        llm_result.get("self_harm_detected", False)
    )

    # Unified self-harm flag
    final_sh_detected = llm_result.get("self_harm_detected", False) or deterministic_sh

    # 4. Determine Actions
    actions = risk_engine.get_actions(final_risk_level)

    # 5. Save Risk Event & Assistant Message
    db.save_risk_event(
        user_id=request.user_id,
        message_id=user_msg_id,
        risk_level=final_risk_level,
        self_harm_detected=final_sh_detected,
        keyword_score=kw_score,
        reasons=reasons
    )

    reply_text = llm_result.get("reply", "I am here for you.")

    # SAFETY OVERRIDE: If LLM failed (fallback used) AND risk is high
    if reply_text == ai_agent.FALLBACK_ERROR_MESSAGE and final_risk_level in ["high", "critical"]:
        reply_text = "I hear that you are in pain. Please reach out for help immediately – you are not alone. I've listed some resources below."

    db.save_message(request.user_id, "assistant", reply_text)

    return {
        "reply": reply_text,
        "risk_level": final_risk_level,
        "self_harm_detected": final_sh_detected,
        "advice": llm_result.get("advice", []),
        "actions": actions,
        "timestamp": datetime.utcnow().isoformat()
    }

@mental_health_router.get("/checkin/today", response_model=CheckinQuestionsResponse)
def mental_health_get_checkin_questions(user_id: str):
    """Get daily check-in questions for user"""
    return {
        "date": date.today().isoformat(),
        "questions": [
            "How are you feeling right now (1–10)?",
            "What was the strongest emotion you felt today?",
            "What triggered stress or anxiety today?",
            "Did you sleep well last night?",
            "Name one thing that helped you get through today.",
            "Have you had any thoughts of hurting yourself?"
        ]
    }

@mental_health_router.post("/checkin/submit", response_model=CheckinSubmitResponse)
def mental_health_submit_checkin(request: CheckinSubmitRequest):
    """Submit daily check-in responses"""
    # 1. Summarize with LLM
    summary_result = ai_agent.summarize_day_llm(request.answers)

    # 2. Save Daily Summary
    db.save_daily_summary(
        user_id=request.user_id,
        date=date.today().isoformat(),
        summary_text=summary_result.get("daily_summary", "Summary unavailable."),
        risk_level=summary_result.get("risk_level", "low")
    )

    # 3. Determine Actions based on summary risk
    actions = risk_engine.get_actions(summary_result.get("risk_level", "low"))

    return {
        "daily_summary": summary_result.get("daily_summary", ""),
        "risk_level": summary_result.get("risk_level", "low"),
        "self_harm_detected": summary_result.get("self_harm_detected", False),
        "advice": summary_result.get("advice", []),
        "actions": actions
    }

# ==========================================
# 3. MEDICINE BACKEND - Direct Router Mounting
# ==========================================
from medicine_backend.medicine_app.routes import medications, reminders, prescriptions

# Create a wrapper router for medicine endpoints
medicine_router = APIRouter(prefix="/medicine-reminder")

# Include the sub-routers as-is (they maintain their original tags for clarity)
medicine_router.include_router(medications.router)
medicine_router.include_router(reminders.router)
medicine_router.include_router(prescriptions.router)

# Add medicine health check under the prefix
@medicine_router.get("/health")
def medicine_health():
    """Medicine service health check"""
    return {"status": "ok"}

# ==========================================
# 4. SOS/EMERGENCY BACKEND - Router Integration
# ==========================================
# Import SOS backend endpoints
try:
    from sos_backend.main import app as sos_app
    SOS_AVAILABLE = True
    
    # Create a wrapper router for SOS endpoints
    sos_router = APIRouter(prefix="/sos", tags=["SOS Emergency"])
    
    # Re-export key SOS endpoints via the gateway
    from sqlmodel import Session
    from sos_backend.database import get_session
    from sos_backend.models import SOSEvent, SOSStatus
    from fastapi.responses import Response
    
    # Explicit OPTIONS handlers for CORS preflight
    @sos_router.options("/active")
    def sos_active_options():
        """Handle CORS preflight for /sos/active"""
        return Response(
            status_code=200,
            headers={
                "Access-Control-Allow-Origin": "*",
                "Access-Control-Allow-Methods": "GET, OPTIONS",
                "Access-Control-Allow-Headers": "*",
            }
        )
    
    @sos_router.get("/active", response_model=List[SOSEvent])
    def gateway_get_active_sos(session: Session = Depends(get_session)):
        """Get all active SOS events for hospital dashboard"""
        from sqlmodel import select
        from datetime import datetime as dt
        
        active_statuses = [SOSStatus.TRIGGERED, SOSStatus.ACKNOWLEDGED, SOSStatus.ON_THE_WAY]
        statement = select(SOSEvent).where(SOSEvent.status.in_(active_statuses))
        results = session.exec(statement).all()
        
        # Filter out events with expired consent (DPDP compliance)
        valid_events = []
        for event in results:
            if event.consent_expires_at:
                if dt.utcnow() < event.consent_expires_at:
                    valid_events.append(event)
            else:
                valid_events.append(event)
        
        return valid_events
    
    @sos_router.get("/{sos_id}", response_model=SOSEvent)
    def gateway_get_sos_status(sos_id: int, session: Session = Depends(get_session)):
        """Get specific SOS event status"""
        event = session.get(SOSEvent, sos_id)
        if not event:
            raise HTTPException(status_code=404, detail="SOS Event not found")
        return event

    @sos_router.get("/{sos_id}/emergency-data")
    def gateway_get_emergency_data(sos_id: int, responder_id: str = "hospital", session: Session = Depends(get_session)):
        """Get emergency data for an active SOS event"""
        from sos_backend.models import UserEmergencyProfile, EmergencyDataResponse
        from sqlmodel import select
        from datetime import datetime as dt
        import json
        
        event = session.get(SOSEvent, sos_id)
        if not event:
            raise HTTPException(status_code=404, detail="SOS Event not found")
        
        # Check consent has not expired
        if event.consent_expires_at and dt.utcnow() > event.consent_expires_at:
            raise HTTPException(status_code=403, detail="Emergency consent has expired")
        
        # Get user's emergency profile
        profile = session.exec(
            select(UserEmergencyProfile).where(UserEmergencyProfile.user_id == event.user_id)
        ).first()
        
        return {
            "user_id": event.user_id,
            "latitude": event.latitude,
            "longitude": event.longitude,
            "emergency_type": event.emergency_type,
            "status": event.status.value,
            "ambulance_id": event.assigned_ambulance_id,
            "name": profile.name if profile and profile.share_name else None,
            "age": profile.age if profile and profile.share_age else None,
            "blood_group": profile.blood_group if profile and profile.share_blood_group else None,
            "allergies": json.loads(profile.allergies) if profile and profile.share_allergies and profile.allergies else None,
            "chronic_conditions": json.loads(profile.chronic_conditions) if profile and profile.share_chronic_conditions and profile.chronic_conditions else None,
            "current_medications": json.loads(profile.current_medications) if profile and profile.share_current_medications and profile.current_medications else None,
            "consent_expires_at": event.consent_expires_at.isoformat() if event.consent_expires_at else None,
        }
    
    print("[Gateway] ✓ SOS Emergency endpoints prepared")
except ImportError as e:
    SOS_AVAILABLE = False
    print(f"[Gateway] ⚠️ SOS backend not available: {e}")

# ==========================================
# 5. DATABASE INITIALIZATION SETUP
# ==========================================
# Fix database paths and create tables for all backends

# Diagnostics: Fix DATABASE_URL to use absolute path
def _setup_diagnostics_db():
    """Initialize diagnostics database with correct path"""
    from diagnostics_backend.diagnostics_app.core.config import settings
    from diagnostics_backend.diagnostics_app.db.base import Base
    from diagnostics_backend.diagnostics_app.db.session import engine
    
    # Ensure tables are created
    Base.metadata.create_all(bind=engine)
    print("[Gateway] ✓ Diagnostics database tables initialized")

# Medicine: Fix DATABASE_URL to use absolute path
def _setup_medicine_db():
    """Initialize medicine database with correct path"""
    from medicine_backend.medicine_app.core.db import engine, Base
    
    # Ensure tables are created
    Base.metadata.create_all(bind=engine)
    print("[Gateway] ✓ Medicine database tables initialized")

# ==========================================
# 4. GATEWAY APPLICATION
# ==========================================
gateway_app = FastAPI(
    title="MySehat Integrated Healthcare Gateway",
    description=(
        "Unified healthcare gateway combining:\n"
        "- **Diagnostics**: AI-powered triage and symptom analysis\n"
        "- **Mental Health**: Mental health screening and crisis detection\n"
        "- **Medicine Reminder**: Prescription and medication reminders"
    ),
    version="1.0.0",
    docs_url="/docs",
    openapi_url="/openapi.json",
)

# ==========================================
# 5. MIDDLEWARE SETUP
# ==========================================
# CORS Configuration - explicit methods for better browser compatibility
gateway_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update for production
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# ==========================================
# 6. STARTUP EVENT - Initialize backends
# ==========================================
@gateway_app.on_event("startup")
def on_startup():
    """Initialize all backend services on startup"""
    # Initialize diagnostics database tables
    try:
        _setup_diagnostics_db()
    except Exception as e:
        print(f"[Gateway] Warning: Diagnostics DB init error: {e}")
    
    # Initialize medicine database tables
    try:
        _setup_medicine_db()
    except Exception as e:
        print(f"[Gateway] Warning: Medicine DB init error: {e}")
    
    # Initialize mental health database
    try:
        db.init_db()
        print("[Gateway] ✓ Mental Health database initialized")
    except Exception as e:
        print(f"[Gateway] Warning: Mental Health DB init error: {e}")
    
    # Initialize SOS database
    if SOS_AVAILABLE:
        try:
            from sos_backend.database import create_db_and_tables
            create_db_and_tables()
            print("[Gateway] ✓ SOS database tables initialized")
        except Exception as e:
            print(f"[Gateway] Warning: SOS DB init error: {e}")
    
    # Initialize Auth database and seed users
    if AUTH_AVAILABLE:
        try:
            init_auth_db()
            seed_auth_db()
            print("[Gateway] ✓ Auth database initialized and seeded")
        except Exception as e:
            print(f"[Gateway] Warning: Auth DB init error: {e}")

# ==========================================
# 7. INCLUDE ROUTERS WITH PROPER TAGGING
# ==========================================

# Diagnostics backend: custom router with Diagnostics tag for consistent grouping
gateway_app.include_router(
    diagnostics_router_custom,
    prefix="/diagnostics",
)

# Mental health backend: already tagged in mental_health_router
# Mount directly (already has /mental-health prefix)
gateway_app.include_router(mental_health_router)

# Medicine backend: already tagged in sub-routers
# Mount under /medicine-reminder prefix
gateway_app.include_router(medicine_router)

# SOS/Emergency backend: Mount if available
if SOS_AVAILABLE:
    gateway_app.include_router(sos_router)
    print("[Gateway] ✓ SOS Emergency endpoints registered at /sos")

# Auth backend: Mount if available
if AUTH_AVAILABLE:
    gateway_app.include_router(auth_router)
    print("[Gateway] ✓ Auth endpoints registered at /auth")

# ==========================================
# FHIR R4 ENDPOINTS - Hospital Interoperability
# ==========================================
# FHIR provides standardized healthcare data exchange
# Hospitals access patient data ONLY through FHIR endpoints
try:
    from fhir_backend.fhir_app.api.api_v1.router import api_router as fhir_router
    
    # Mount FHIR endpoints at /fhir prefix
    gateway_app.include_router(
        fhir_router,
        prefix="/fhir",
        tags=["FHIR R4"]
    )
    FHIR_AVAILABLE = True
    print("[Gateway] ✓ FHIR R4 endpoints registered at /fhir")
except ImportError as e:
    FHIR_AVAILABLE = False
    print(f"[Gateway] ⚠️ FHIR backend not available: {e}")

# ==========================================
# DPDP COMPLIANCE ENDPOINTS
# ==========================================
# Provide unified consent management endpoints at gateway level
# So Flutter app can manage all consent from a single base URL
if DPDP_AVAILABLE:
    gateway_app.include_router(
        create_consent_router("mysehat_gateway"), 
        prefix="/api/v1", 
        tags=["DPDP Consent"]
    )
    gateway_app.include_router(
        create_user_rights_router("mysehat_gateway"), 
        prefix="/api/v1", 
        tags=["DPDP User Rights"]
    )
    gateway_app.include_router(
        create_audit_router("mysehat_gateway"), 
        prefix="/api/v1", 
        tags=["DPDP Audit"]
    )
    print("[Gateway] ✓ DPDP consent and user rights endpoints registered")

# ==========================================
# 8. ROOT ENDPOINT
# ==========================================
@gateway_app.get("/", tags=["Gateway"])
def root():
    """Gateway health and information endpoint"""
    return {
        "message": "Welcome to MySehat Integrated Healthcare Gateway",
        "version": "2.0.0",
        "dpdp_compliant": DPDP_AVAILABLE,
        "fhir_enabled": FHIR_AVAILABLE if 'FHIR_AVAILABLE' in dir() else False,
        "sos_enabled": SOS_AVAILABLE if 'SOS_AVAILABLE' in dir() else False,
        "auth_enabled": AUTH_AVAILABLE if 'AUTH_AVAILABLE' in dir() else False,
        "services": {
            "diagnostics": "/diagnostics/docs",
            "mental_health": "/mental-health/docs",
            "medicine_reminder": "/medicine-reminder/docs",
            "sos_emergency": "/sos/active" if 'SOS_AVAILABLE' in dir() and SOS_AVAILABLE else None,
            "fhir": "/fhir/metadata" if 'FHIR_AVAILABLE' in dir() and FHIR_AVAILABLE else None,
            "auth": "/auth/health" if 'AUTH_AVAILABLE' in dir() and AUTH_AVAILABLE else None,
        },
        "sos_endpoints": {
            "active_emergencies": "/sos/active",
            "sos_status": "/sos/{sos_id}",
            "emergency_data": "/sos/{sos_id}/emergency-data",
        } if 'SOS_AVAILABLE' in dir() and SOS_AVAILABLE else None,
        "fhir_endpoints": {
            "patient": "/fhir/Patient/{id}",
            "observations": "/fhir/Observation?patient={id}",
            "medications": "/fhir/MedicationRequest?patient={id}",
            "documents": "/fhir/DocumentReference?patient={id}",
            "emergency_bundle": "/fhir/Bundle/emergency/{patient_id}",
            "full_bundle": "/fhir/Bundle/{patient_id}",
        } if 'FHIR_AVAILABLE' in dir() and FHIR_AVAILABLE else None,
        "dpdp_endpoints": {
            "consent": "/api/v1/consent",
            "my_data": "/api/v1/my-data",
            "audit": "/api/v1/audit",
        } if DPDP_AVAILABLE else None,
        "auth_endpoints": {
            "signup": "/auth/signup",
            "login": "/auth/login",
            "logout": "/auth/logout",
            "validate": "/auth/validate",
            "me": "/auth/me",
            "users": "/auth/users",
            "preferences": "/auth/preferences",
            "consents": "/auth/consents",
        } if AUTH_AVAILABLE else None,
        "all_endpoints": "/docs"
    }

@gateway_app.get("/health", tags=["Gateway"])
def gateway_health():
    """Gateway health check"""
    return {
        "status": "ok", 
        "timestamp": datetime.utcnow().isoformat(),
        "dpdp_compliant": DPDP_AVAILABLE,
        "fhir_enabled": FHIR_AVAILABLE if 'FHIR_AVAILABLE' in dir() else False,
        "sos_enabled": SOS_AVAILABLE if 'SOS_AVAILABLE' in dir() else False,
        "auth_enabled": AUTH_AVAILABLE if 'AUTH_AVAILABLE' in dir() else False
    }

# ==========================================
# 9. EXTENSIBILITY GUIDE
# ==========================================
"""
TO ADD A NEW BACKEND (e.g., Lab Tests):

1. Create the new backend folder:
   lab_tests_backend/
   └── lab_tests_app/
       └── main.py (with app or routers)

2. Add 3 lines to gateway/main.py:

   # Import
   from lab_tests_backend.lab_tests_app.api import lab_router
   
   # Create router if needed
   lab_router_prefixed = APIRouter(prefix="/lab-tests", tags=["Lab Tests"])
   lab_router_prefixed.include_router(lab_router)
   
   # Mount
   gateway_app.include_router(lab_router_prefixed)

That's it! The Swagger UI will auto-update with the new endpoints.
"""

# ==========================================
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "gateway.main:gateway_app",
        host="0.0.0.0",
        port=8000,
        reload=True,
    )
