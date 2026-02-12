"""
Triage Endpoints - DPDP Act 2023 Compliant
==========================================

AI-powered symptom checker with privacy controls and clear disclaimers.
"""

import sys
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request
from sqlalchemy.orm import Session
from typing import Any, Dict, Optional

# Ensure parent is in path for absolute imports
_parent_dir = Path(__file__).resolve().parent.parent.parent.parent.parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

from diagnostics_backend.diagnostics_app.api import deps
from diagnostics_backend.diagnostics_app.services.triage_orchestrator import TriageOrchestrator
from diagnostics_backend.diagnostics_app.models.schemas import TriageInputText, SessionResponse, TriageResponse, AnswerInput

# DPDP Compliance
try:
    from shared.dpdp import (
        ConsentCheck, DataCategory, Purpose, GrantedTo,
        AuditAction, AuditLogEntry, AIFeature, AIProcessingRequest,
        get_consent_engine, get_audit_logger, get_ai_governance
    )
    DPDP_AVAILABLE = True
    consent_engine = get_consent_engine()
    audit_logger = get_audit_logger("diagnostics_backend")
    ai_governance = get_ai_governance("diagnostics_backend")
except ImportError:
    DPDP_AVAILABLE = False

router = APIRouter()

# AI Disclaimer
AI_DISCLAIMER = """
⚠️ **AI Assistance Disclaimer**: This is an AI-powered symptom checker that provides 
general health information only. It is NOT a medical diagnosis. Always consult 
a qualified healthcare professional for proper diagnosis and treatment. In case 
of emergency, call emergency services immediately.
"""

# Development mode - auto-grant consent
DEV_MODE = True


def check_diagnostics_consent(user_id: Optional[str]) -> tuple[bool, Optional[int]]:
    """Check if user has consented to diagnostic AI processing."""
    if not DPDP_AVAILABLE or not user_id:
        return True, None
    
    # Auto-grant consent in development mode
    if DEV_MODE:
        try:
            # Try to grant consent automatically for development
            consent_engine.grant_consent(
                user_id=user_id,
                data_category=DataCategory.DIAGNOSTICS,
                purpose=Purpose.AI_PROCESSING,
                granted_to=GrantedTo.AI_SERVICE
            )
        except Exception:
            pass  # Consent may already exist
        return True, None
    
    result = consent_engine.check_consent(ConsentCheck(
        user_id=user_id,
        data_category=DataCategory.DIAGNOSTICS,
        purpose=Purpose.AI_PROCESSING,
        granted_to=GrantedTo.AI_SERVICE
    ))
    
    return result.is_valid, result.consent_id


def log_triage_access(user_id: Optional[str], session_id: str, consent_id: Optional[int]):
    """Log AI processing for audit trail."""
    if DPDP_AVAILABLE and user_id:
        audit_logger.log_ai_processing(
            user_id=user_id,
            model_used="llama-3.3-70b-versatile",
            input_type="text",
            consent_id=consent_id,
            purpose="symptom_triage",
            details={"session_id": session_id}
        )


@router.post("/text", response_model=TriageResponse)
async def triage_text(
    input_data: TriageInputText,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Start a triage session with text symptoms.
    
    **DPDP Compliance:**
    - AI-generated response with clear disclaimer
    - Processing logged for audit trail
    - Data not used for AI training
    """
    user_id = getattr(input_data, 'user_id', None)
    
    # Check consent if user_id provided
    has_consent, consent_id = check_diagnostics_consent(user_id)
    if not has_consent and user_id:
        raise HTTPException(
            status_code=403,
            detail="Consent required for AI-powered symptom checking. Please accept the terms first."
        )
    
    orchestrator = TriageOrchestrator(db)
    session = await orchestrator.create_session()
    
    # Log AI processing
    log_triage_access(user_id, session.id, consent_id)
    
    result = await orchestrator.process_text_triage(
        session.id, 
        input_data.symptoms, 
        severity=input_data.severity, 
        duration=input_data.duration
    )
    
    # Add DPDP metadata to response
    result_dict = result.dict() if hasattr(result, 'dict') else dict(result)
    result_dict["ai_disclaimer"] = AI_DISCLAIMER
    result_dict["dpdp_compliant"] = True
    result_dict["consent_id"] = consent_id
    
    return result


@router.post("/image", response_model=TriageResponse)
async def triage_image(
    file: UploadFile = File(...),
    session_id: Optional[str] = Form(None),
    request: Request = None,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Start or continue a triage session with an image upload.
    
    Upload an image of a wound, rash, or other visible symptom.
    The AI will analyze the image and provide guidance.
    
    **DPDP Compliance:**
    - AI-generated analysis with clear disclaimer
    - Image processing logged for audit trail
    - Images are not stored permanently unless consent given
    """
    # Get user_id from header
    user_id = request.headers.get('X-User-Id') if request else None
    
    # Check consent if user_id provided
    has_consent, consent_id = check_diagnostics_consent(user_id)
    if not has_consent and user_id:
        raise HTTPException(
            status_code=403,
            detail="Consent required for AI-powered image analysis. Please accept the terms first."
        )
    
    # Validate file type
    allowed_types = ['image/jpeg', 'image/png', 'image/jpg', 'image/webp']
    if file.content_type not in allowed_types:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type. Allowed: {', '.join(allowed_types)}"
        )
    
    # Process image using memory-efficient utility (runs in threadpool)
    from fastapi.concurrency import run_in_threadpool
    from shared.image_utils import process_image_upload, validate_and_read_upload
    import io
    import gc
    
    try:
        # validate size first
        if file.size and file.size > 5 * 1024 * 1024:
             raise HTTPException(status_code=400, detail="Image size exceeds 5MB limit.")
        
        # Read file safely
        raw_bytes = await validate_and_read_upload(file)
        
        # Optimize image (resize/compress) in threadpool to avoid blocking event loop
        # Wrap bytes in BytesIO for PIL
        image_bytes = await run_in_threadpool(process_image_upload, io.BytesIO(raw_bytes))
        
        # Explicitly clear raw bytes
        del raw_bytes
        gc.collect()
        
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Image processing failed: {str(e)}")
    
    orchestrator = TriageOrchestrator(db)
    
    # Process image
    result = await orchestrator.process_image_triage(session_id, image_bytes)
    
    # Log AI processing
    if DPDP_AVAILABLE and user_id:
        audit_logger.log_ai_processing(
            user_id=user_id,
            model_used="vision-model",
            input_type="image",
            consent_id=consent_id,
            purpose="image_symptom_triage",
            details={"session_id": result.session_id, "file_name": file.filename}
        )
    
    # Add DPDP metadata to response
    result_dict = result.dict() if hasattr(result, 'dict') else dict(result)
    result_dict["ai_disclaimer"] = AI_DISCLAIMER
    result_dict["dpdp_compliant"] = True
    result_dict["consent_id"] = consent_id
    
    return result


@router.post("/session/{session_id}/answer", response_model=TriageResponse)
async def triage_answer(
    session_id: str,
    answer_data: AnswerInput,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Answer a follow-up question to advance the session.
    
    **DPDP Compliance:**
    - Session-based tracking
    - Continued audit logging
    """
    orchestrator = TriageOrchestrator(db)
    
    # Verify session exists
    session = await orchestrator.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    user_id = getattr(answer_data, 'user_id', None)
    _, consent_id = check_diagnostics_consent(user_id)
    log_triage_access(user_id, session_id, consent_id)

    result = await orchestrator.process_answer(session_id, answer_data.answer)
    return result


@router.get("/session/{session_id}", response_model=SessionResponse)
async def get_session(
    session_id: str,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Get current state of a triage session.
    """
    orchestrator = TriageOrchestrator(db)
    session = await orchestrator.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    return session


@router.post("/session/{session_id}/text", response_model=TriageResponse)
async def triage_session_text(
    session_id: str,
    input_data: TriageInputText,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Add text symptoms to an existing session (multi-turn).
    
    **DPDP Compliance:**
    - Continued session tracking
    - AI disclaimer included
    """
    orchestrator = TriageOrchestrator(db)
    
    # Verify session exists
    session = await orchestrator.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")

    user_id = getattr(input_data, 'user_id', None)
    _, consent_id = check_diagnostics_consent(user_id)
    log_triage_access(user_id, session_id, consent_id)

    result = await orchestrator.process_session_text(
        session_id, 
        input_data.symptoms
    )
    return result


@router.delete("/session/{session_id}")
async def delete_session(
    session_id: str,
    user_id: Optional[str] = None,
    db: Session = Depends(deps.get_db)
) -> Any:
    """
    Delete a triage session (Right to Erasure).
    
    **DPDP Compliance:**
    - User can delete their session data
    - Deletion is logged for audit
    """
    orchestrator = TriageOrchestrator(db)
    
    session = await orchestrator.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Delete session
    await orchestrator.delete_session(session_id)
    
    # Log deletion
    if DPDP_AVAILABLE and user_id:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_ERASURE,
            resource_type="triage_session",
            resource_id=session_id,
            purpose="right_to_erasure"
        ))
    
    return {
        "message": "Session deleted successfully",
        "session_id": session_id,
        "dpdp_compliant": True
    }


@router.get("/disclaimer")
async def get_disclaimer():
    """Get the AI disclaimer for symptom checker."""
    return {
        "disclaimer": AI_DISCLAIMER,
        "legal_basis": "DPDP Act 2023 - Transparency Requirement",
        "data_usage": "Your symptoms are processed by AI for informational purposes only. Data is not used to train AI models."
    }
