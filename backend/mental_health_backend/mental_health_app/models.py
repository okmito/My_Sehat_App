from pydantic import BaseModel
from typing import List, Optional, Dict, Any

# Chat
class ChatRequest(BaseModel):
    user_id: str
    message: str

class ChatResponse(BaseModel):
    reply: str
    risk_level: str
    self_harm_detected: bool
    advice: List[str]
    actions: List[str]
    timestamp: str
    ai_disclaimer: Optional[str] = None
    session_mode: Optional[bool] = False
    dpdp_compliant: Optional[bool] = True

# Daily Check-in
class CheckinQuestionsResponse(BaseModel):
    date: str
    questions: List[str]

class CheckinSubmitRequest(BaseModel):
    user_id: str
    answers: Dict[str, str]

class CheckinSubmitResponse(BaseModel):
    daily_summary: str
    risk_level: str
    self_harm_detected: bool
    advice: List[str]
    actions: List[str]
    dpdp_compliant: Optional[bool] = True


# DPDP Consent Models
class MentalHealthConsentRequest(BaseModel):
    """Request model for granting mental health AI consent"""
    user_id: str
    consent_text: Optional[str] = None
    session_only: bool = False  # If True, no data is stored
    allow_storage: bool = True  # If False, runs in session-only mode


class MentalHealthConsentResponse(BaseModel):
    """Response model for consent operations"""
    success: bool
    consent_id: Optional[int] = None
    message: str


# User Data Rights Models (DPDP Act)
class UserDataExportResponse(BaseModel):
    """Response model for data export (Right to Access)"""
    user_id: str
    export_date: str
    messages: List[Dict[str, Any]]
    risk_events: List[Dict[str, Any]]
    daily_summaries: List[Dict[str, Any]]
    preferences: Optional[Dict[str, Any]] = None
    dpdp_notice: str


class DataDeletionResponse(BaseModel):
    """Response model for data deletion (Right to Erasure)"""
    success: bool
    message: str
    records_deleted: int
