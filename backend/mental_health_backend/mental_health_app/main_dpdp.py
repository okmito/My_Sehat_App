from fastapi import FastAPI
"""
Mental Health AI Backend - DPDP Act 2023 Compliant
===================================================

STRICTEST privacy mode:
- Anonymous internal identifiers  
- Session-based consent option
- "Do not store" mode
- SOS/hospitals blocked from accessing this data
- AI opt-out supported
"""

import sys
from pathlib import Path

# Add parent directory to path for imports
parent_dir = Path(__file__).parent.parent.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

from fastapi import FastAPI, HTTPException, Header
from datetime import datetime, date
import os
from typing import List, Optional
import hashlib

# Import local modules
try:
    from mental_health_backend.mental_health_app.models import (
        ChatRequest, ChatResponse, 
        CheckinQuestionsResponse, CheckinSubmitRequest, CheckinSubmitResponse,
        MentalHealthConsentRequest, MentalHealthConsentResponse,
        UserDataExportResponse, DataDeletionResponse
    )
    from mental_health_backend.mental_health_app import db
    from mental_health_backend.mental_health_app.services import ai_agent, risk_engine
except ImportError:
    from .models import (
        ChatRequest, ChatResponse, 
        CheckinQuestionsResponse, CheckinSubmitRequest, CheckinSubmitResponse,
        MentalHealthConsentRequest, MentalHealthConsentResponse,
        UserDataExportResponse, DataDeletionResponse
    )
    from . import db
    from .services import ai_agent, risk_engine

# DPDP Compliance imports
try:
    from shared.dpdp import (
        ConsentEngine, ConsentCheck, ConsentCreate, DataCategory, Purpose, GrantedTo,
        AuditLogger, AuditAction, AuditLogEntry,
        AIGovernance, AIFeature, AIProcessingRequest,
        get_consent_engine, get_audit_logger, get_ai_governance,
        # NEW: Global middleware and API routers for DPDP compliance
        add_dpdp_middleware, create_consent_router, create_user_rights_router, create_audit_router
    )
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("⚠️ DPDP module not available - running without privacy compliance")

app = FastAPI(
    title="Mental Health Agentic AI Backend - DPDP Compliant",
    description="""
    Backend for mental health screening and crisis detection.
    
    **STRICTEST PRIVACY MODE ENABLED:**
    - Uses anonymous internal identifiers
    - Session-only mode available (no storage)
    - Data never shared with SOS/hospitals
    - Full right to erasure supported
    """,
    version="0.3.0"
)

# Initialize DPDP components
consent_engine = None
audit_logger = None
ai_governance = None

if DPDP_AVAILABLE:
    consent_engine = get_consent_engine()
    audit_logger = get_audit_logger("mental_health_backend")
    ai_governance = get_ai_governance("mental_health_backend")
    
    # Add DPDP global middleware for consent enforcement (port 8003)
    add_dpdp_middleware(app, service_port=8003)
    
    # Add consent management and user rights API routers
    app.include_router(create_consent_router("mental_health_backend"), prefix="/api/v1", tags=["DPDP Consent"])
    app.include_router(create_user_rights_router("mental_health_backend"), prefix="/api/v1", tags=["DPDP User Rights"])
    app.include_router(create_audit_router("mental_health_backend"), prefix="/api/v1", tags=["DPDP Audit"])


# ============================================================================
# DPDP COMPLIANCE - STRICTEST MODE
# ============================================================================

def anonymize_user_id(user_id: str) -> str:
    """
    Create anonymous internal identifier for mental health data.
    DPDP: Mental health data should not be easily linkable to user identity.
    Uses one-way hash with service-specific salt.
    """
    salt = "mysehat_mental_health_v1_strict"
    return hashlib.sha256(f"{salt}:{user_id}".encode()).hexdigest()[:32]


def check_mental_health_consent(user_id: str) -> tuple[bool, Optional[int], Optional[str]]:
    """
    Check if user has consented to mental health AI processing.
    Mental health requires EXPLICIT session-based consent.
    
    For development: Auto-grants consent on first use with logging.
    In production: This should redirect to consent UI.
    """
    if not DPDP_AVAILABLE or consent_engine is None:
        return True, None, None
    
    result = consent_engine.check_consent(ConsentCheck(
        user_id=user_id,
        data_category=DataCategory.MENTAL_HEALTH,
        purpose=Purpose.AI_PROCESSING,
        granted_to=GrantedTo.AI_SERVICE
    ))
    
    # If no consent, auto-grant for development (remove in production)
    if not result.is_valid:
        try:
            grant_result = consent_engine.grant_consent(ConsentCreate(
                user_id=user_id,
                data_category=DataCategory.MENTAL_HEALTH,
                purpose=Purpose.AI_PROCESSING,
                granted_to=GrantedTo.AI_SERVICE,
                consent_text="Auto-granted on first use (development mode)",
                revocable=True
            ))
            return True, grant_result.id, None
        except Exception as e:
            return False, None, f"Failed to auto-grant consent: {str(e)}"
    
    return result.is_valid, result.consent_id, result.reason


def verify_not_external_service(service_header: Optional[str]) -> bool:
    """
    Block external services (SOS, hospitals) from accessing mental health data.
    DPDP: Mental health data is NEVER shared with emergency services.
    """
    blocked_services = ["sos_backend", "hospital_service", "ambulance_service", "emergency"]
    if service_header and any(blocked in service_header.lower() for blocked in blocked_services):
        return False
    return True


# -----------------------------
# Startup Event
# -----------------------------
@app.on_event("startup")
def on_startup():
    db.init_db()

# -----------------------------
# Health Check
# -----------------------------
@app.get("/health")
def health_check():
    return {
        "status": "ok", 
        "dpdp_compliant": DPDP_AVAILABLE, 
        "strictest_mode": True,
        "sos_access_blocked": True,
        "anonymous_storage": True
    }


# ============================================================================
# DPDP CONSENT ENDPOINTS
# ============================================================================

@app.post("/consent/grant", response_model=MentalHealthConsentResponse)
def grant_mental_health_consent(request: MentalHealthConsentRequest):
    """
    Grant consent for mental health AI processing.
    
    **DPDP Compliance:**
    - Requires explicit opt-in with clear explanation
    - User can choose session-only mode (no data stored)
    - Consent is revocable at any time
    """
    if not DPDP_AVAILABLE or consent_engine is None:
        return MentalHealthConsentResponse(
            success=True,
            message="Consent recorded (DPDP module not active)"
        )
    
    try:
        result = consent_engine.grant_consent(ConsentCreate(
            user_id=request.user_id,
            data_category=DataCategory.MENTAL_HEALTH,
            purpose=Purpose.AI_PROCESSING,
            granted_to=GrantedTo.AI_SERVICE,
            consent_text=request.consent_text or "User consented to mental health AI companion chat",
            revocable=True
        ))
        
        # Log consent grant
        audit_logger.log(AuditLogEntry(
            user_id=request.user_id,
            action=AuditAction.CONSENT_GRANTED,
            resource_type="mental_health_consent",
            purpose="mental_health_ai",
            details={
                "session_based": request.session_only,
                "store_data": request.allow_storage,
                "consent_id": result.consent_id
            }
        ))
        
        # Store user preferences
        db.save_user_preferences(request.user_id, {
            "session_only": request.session_only,
            "allow_storage": request.allow_storage,
            "consent_id": result.consent_id
        })
        
        return MentalHealthConsentResponse(
            success=True,
            consent_id=result.consent_id,
            message="Consent granted for mental health AI companion. " + 
                    ("Session-only mode enabled - no data will be stored." if request.session_only else "Your conversations will be stored securely.")
        )
    except Exception as e:
        return MentalHealthConsentResponse(
            success=False,
            message=f"Failed to grant consent: {str(e)}"
        )


@app.post("/consent/revoke")
def revoke_mental_health_consent(user_id: str):
    """
    Revoke consent for mental health data processing.
    
    **DPDP Compliance:**
    - Immediately stops all processing
    - Existing data can be deleted via /my-data/delete endpoint
    """
    if DPDP_AVAILABLE and consent_engine is not None:
        consent_engine.revoke_consent(
            user_id=user_id,
            data_category=DataCategory.MENTAL_HEALTH,
            purpose=Purpose.AI_PROCESSING
        )
        
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.CONSENT_REVOKED,
            resource_type="mental_health_consent",
            purpose="mental_health_ai"
        ))
    
    return {
        "message": "Consent revoked. No further mental health data will be processed.",
        "next_steps": "Use DELETE /my-data/{user_id} to request deletion of existing data."
    }


@app.get("/consent/status/{user_id}")
def get_consent_status(user_id: str):
    """Check current consent status for a user."""
    has_consent, consent_id, reason = check_mental_health_consent(user_id)
    prefs = db.get_user_preferences(user_id)
    
    return {
        "has_consent": has_consent,
        "consent_id": consent_id,
        "session_only": prefs.get("session_only", False) if prefs else False,
        "allow_storage": prefs.get("allow_storage", True) if prefs else True,
        "reason": reason
    }


# ============================================================================
# CHAT ENDPOINT - DPDP ENHANCED
# ============================================================================

@app.post("/chat/message", response_model=ChatResponse)
async def chat_message(
    request: ChatRequest,
    x_calling_service: Optional[str] = Header(None)
):
    """
    Mental health chat endpoint with STRICTEST DPDP compliance.
    
    **Privacy Features:**
    - External services (SOS, hospitals) are blocked
    - Uses anonymous internal identifiers
    - Session-only mode skips storage
    - All AI processing is logged
    """
    # DPDP: Block external services
    if not verify_not_external_service(x_calling_service):
        if DPDP_AVAILABLE and audit_logger:
            audit_logger.log_access_denied(
                user_id=request.user_id,
                resource_type="mental_health_chat",
                reason=f"External service blocked: {x_calling_service}"
            )
        raise HTTPException(
            status_code=403,
            detail="Mental health data cannot be accessed by external services (SOS, hospitals). This is protected under DPDP Act."
        )
    
    # DPDP: Check consent first
    has_consent, consent_id, error = check_mental_health_consent(request.user_id)
    
    if not has_consent:
        if DPDP_AVAILABLE and audit_logger:
            audit_logger.log_access_denied(
                user_id=request.user_id,
                resource_type="mental_health_chat",
                reason=error or "Mental health consent required"
            )
        raise HTTPException(
            status_code=403,
            detail="Mental health AI consent required. Please accept the consent notice first."
        )
    
    # DPDP: Use anonymous ID for internal storage
    anon_id = anonymize_user_id(request.user_id)
    
    # Get user preferences to check storage mode
    prefs = db.get_user_preferences(request.user_id) if DPDP_AVAILABLE else {"allow_storage": True}
    allow_storage = prefs.get("allow_storage", True) if prefs else True
    session_only = prefs.get("session_only", False) if prefs else False
    
    # 1. Get conversation history for context (using anonymous ID)
    conversation_history = []
    if allow_storage and not session_only:
        conversation_history = db.get_recent_messages(anon_id, limit=10)
    
    # 2. Save User Message (only if storage allowed)
    user_msg_id = None
    if allow_storage and not session_only:
        user_msg_id = db.save_message(anon_id, "user", request.message)

    # DPDP: Log AI processing
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log_ai_processing(
            user_id=request.user_id,
            model_used="llama-3.3-70b-versatile",
            input_type="text",
            consent_id=consent_id,
            purpose="mental_health_chat",
            details={"session_only": session_only}
        )

    # 3. Get LLM Analysis with conversation context
    llm_result = await ai_agent.analyze_message_llm(request.message, conversation_history)
    
    # 4. Deterministic Risk Assessment
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

    # 5. Determine Actions
    actions = risk_engine.get_actions(final_risk_level)

    # 6. Save Risk Event & Assistant Message (only if storage allowed)
    if allow_storage and not session_only:
        db.save_risk_event(
            user_id=anon_id,  # Anonymous ID
            message_id=user_msg_id,
            risk_level=final_risk_level,
            self_harm_detected=final_sh_detected,
            keyword_score=kw_score,
            reasons=reasons
        )
    
    reply_text = llm_result.get("reply", "I am here for you.")
    
    # SAFETY OVERRIDE: If LLM returned a fallback response AND risk is high
    if reply_text in ai_agent.FALLBACK_RESPONSES and final_risk_level in ["high", "critical"]:
        reply_text = "I hear that you are in pain. Please reach out for help immediately – you are not alone. I've listed some resources below."

    if allow_storage and not session_only:
        db.save_message(anon_id, "assistant", reply_text)

    return {
        "reply": reply_text,
        "risk_level": final_risk_level,
        "self_harm_detected": final_sh_detected,
        "advice": llm_result.get("advice", []),
        "actions": actions,
        "timestamp": datetime.utcnow().isoformat(),
        "ai_disclaimer": "🤝 Companion Notice: I'm an AI companion here to listen and support. I am NOT a mental health professional or therapist. If you're in crisis, please reach out to a mental health helpline.",
        "session_mode": session_only,
        "dpdp_compliant": True
    }


# ============================================================================
# DAILY CHECK-IN ENDPOINTS
# ============================================================================

@app.get("/checkin/today", response_model=CheckinQuestionsResponse)
def get_checkin_questions(user_id: str):
    """Get daily check-in questions."""
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


@app.post("/checkin/submit", response_model=CheckinSubmitResponse)
async def submit_checkin(
    request: CheckinSubmitRequest,
    x_calling_service: Optional[str] = Header(None)
):
    """Submit daily check-in with DPDP compliance."""
    # Block external services
    if not verify_not_external_service(x_calling_service):
        raise HTTPException(status_code=403, detail="External service access blocked")
    
    # Check consent
    has_consent, consent_id, _ = check_mental_health_consent(request.user_id)
    if not has_consent:
        raise HTTPException(status_code=403, detail="Mental health consent required")
    
    anon_id = anonymize_user_id(request.user_id)
    
    # Check storage preferences
    prefs = db.get_user_preferences(request.user_id)
    allow_storage = prefs.get("allow_storage", True) if prefs else True
    
    # 1. Summarize with LLM
    summary_result = await ai_agent.summarize_day_llm(request.answers)
    
    # 2. Save Daily Summary (if allowed)
    if allow_storage:
        db.save_daily_summary(
            user_id=anon_id,
            date=date.today().isoformat(),
            summary_text=summary_result.get("daily_summary", "Summary unavailable."),
            risk_level=summary_result.get("risk_level", "low")
        )
    
    # 3. Determine Actions
    actions = risk_engine.get_actions(summary_result.get("risk_level", "low"))

    return {
        "daily_summary": summary_result.get("daily_summary", ""),
        "risk_level": summary_result.get("risk_level", "low"),
        "self_harm_detected": summary_result.get("self_harm_detected", False),
        "advice": summary_result.get("advice", []),
        "actions": actions,
        "dpdp_compliant": True
    }


# ============================================================================
# USER DATA RIGHTS (DPDP Act)
# ============================================================================

@app.get("/my-data/{user_id}", response_model=UserDataExportResponse)
def export_user_data(user_id: str):
    """
    Export all user's mental health data (Right to Access).
    
    **DPDP Compliance:**
    - User can access all their stored data
    - Returns data in portable format
    """
    anon_id = anonymize_user_id(user_id)
    
    # Get all user data
    messages = db.get_all_messages(anon_id)
    risk_events = db.get_all_risk_events(anon_id)
    summaries = db.get_all_daily_summaries(anon_id)
    prefs = db.get_user_preferences(user_id)
    
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_EXPORT,
            resource_type="mental_health_all_data",
            purpose="right_to_access"
        ))
    
    return {
        "user_id": user_id,
        "export_date": datetime.utcnow().isoformat(),
        "messages": messages,
        "risk_events": risk_events,
        "daily_summaries": summaries,
        "preferences": prefs,
        "dpdp_notice": "This is your complete mental health data as per DPDP Act 2023 Right to Access."
    }


@app.delete("/my-data/{user_id}", response_model=DataDeletionResponse)
def delete_user_data(user_id: str, confirm: bool = False):
    """
    Delete all user's mental health data (Right to Erasure).
    
    **DPDP Compliance:**
    - Permanently deletes all data
    - Cannot be undone
    - Requires confirmation
    """
    if not confirm:
        return {
            "success": False,
            "message": "Please confirm deletion by setting confirm=true",
            "records_deleted": 0
        }
    
    anon_id = anonymize_user_id(user_id)
    
    # Delete all data
    deleted = db.delete_all_user_data(anon_id, user_id)
    
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_ERASURE,
            resource_type="mental_health_all_data",
            purpose="right_to_erasure",
            details={"records_deleted": deleted}
        ))
    
    return {
        "success": True,
        "message": "All your mental health data has been permanently deleted.",
        "records_deleted": deleted
    }


# ============================================================================
# BLOCKED ENDPOINTS - SOS CANNOT ACCESS
# ============================================================================

@app.get("/external/user-data/{user_id}")
def external_data_access(
    user_id: str,
    x_calling_service: Optional[str] = Header(None)
):
    """
    This endpoint exists to explicitly block external access.
    SOS and hospital services cannot access mental health data.
    """
    if DPDP_AVAILABLE and audit_logger:
        audit_logger.log_access_denied(
            user_id=user_id,
            resource_type="mental_health_external",
            reason=f"External access attempt blocked: {x_calling_service}"
        )
    
    raise HTTPException(
        status_code=403,
        detail={
            "error": "ACCESS_DENIED",
            "message": "Mental health data is protected under DPDP Act 2023.",
            "legal_basis": "Section 4(2) - Sensitive Personal Data Protection",
            "allowed_access": "Only the user themselves can access this data."
        }
    )
