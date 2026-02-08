"""
AI Governance Module - DPDP Act 2023 Compliance
================================================

Ensures AI transparency, user control, and accountability:
- AI opt-out per feature
- Clear disclaimers
- No cross-user learning
- Consent-based processing
- Audit trail for AI operations
"""

from enum import Enum
from datetime import datetime
from typing import Optional, Dict, Any, List
from pydantic import BaseModel
from .consent import ConsentEngine, ConsentCheck, DataCategory, Purpose, GrantedTo, get_consent_engine
from .audit import AuditLogger, AuditAction, get_audit_logger


class AIFeature(str, Enum):
    """AI features that require governance"""
    SYMPTOM_CHECKER = "symptom_checker"
    MENTAL_HEALTH_CHAT = "mental_health_chat"
    DOCUMENT_ANALYSIS = "document_analysis"
    HEALTH_INSIGHTS = "health_insights"
    MEDICATION_INTERACTION = "medication_interaction"


class AIModel(str, Enum):
    """AI models used in the platform"""
    LLAMA_TEXT = "llama-3.3-70b-versatile"
    LLAMA_VISION = "llama-3.2-11b-vision-preview"
    LLAMA_VISION_LARGE = "llama-3.2-90b-vision-preview"


# Standard disclaimers
DISCLAIMERS = {
    AIFeature.SYMPTOM_CHECKER: (
        "⚠️ AI Assistance Disclaimer: This is an AI-powered symptom checker that provides "
        "general health information only. It is NOT a medical diagnosis. Always consult "
        "a qualified healthcare professional for proper diagnosis and treatment. In case "
        "of emergency, call emergency services immediately."
    ),
    AIFeature.MENTAL_HEALTH_CHAT: (
        "🤝 Companion Notice: I'm an AI companion here to listen and support. I am NOT a "
        "mental health professional or therapist. If you're in crisis or having thoughts "
        "of self-harm, please reach out to a mental health helpline or emergency services."
    ),
    AIFeature.DOCUMENT_ANALYSIS: (
        "📄 Document Analysis: Information extracted by AI from your documents. Please verify "
        "all extracted data for accuracy. This is not a medical interpretation. Consult your "
        "healthcare provider for clinical decisions."
    ),
    AIFeature.HEALTH_INSIGHTS: (
        "📊 Health Insights: AI-generated observations based on your data. These are informational "
        "only and should not replace professional medical advice."
    ),
    AIFeature.MEDICATION_INTERACTION: (
        "💊 Medication Information: AI-assisted drug interaction check. Always verify with your "
        "pharmacist or doctor before making any medication changes."
    )
}


class AIProcessingRequest(BaseModel):
    """Request for AI processing with consent"""
    user_id: str
    feature: AIFeature
    input_type: str  # text, image, document
    input_summary: Optional[str] = None  # Sanitized summary (no PII in logs)


class AIProcessingResult(BaseModel):
    """Result wrapper for AI processing"""
    success: bool
    result: Optional[Dict[str, Any]] = None
    disclaimer: str
    consent_id: Optional[int] = None
    audit_id: Optional[int] = None
    error: Optional[str] = None


class AIGovernance:
    """
    AI Governance layer for DPDP compliance.
    
    Ensures:
    1. User has consented to AI processing
    2. User can opt-out at any time
    3. All AI processing is logged
    4. Clear disclaimers are shown
    5. No cross-user data usage
    """
    
    def __init__(self, service_name: str):
        self.service_name = service_name
        self.consent_engine = get_consent_engine()
        self.audit_logger = get_audit_logger(service_name)
        
        # Track opt-out preferences
        self._opt_outs: Dict[str, List[AIFeature]] = {}
    
    def get_disclaimer(self, feature: AIFeature) -> str:
        """Get the appropriate disclaimer for an AI feature"""
        return DISCLAIMERS.get(feature, DISCLAIMERS[AIFeature.HEALTH_INSIGHTS])
    
    def check_ai_consent(self, user_id: str, feature: AIFeature) -> tuple[bool, Optional[int], Optional[str]]:
        """
        Check if user has consented to AI processing.
        
        Returns: (is_valid, consent_id, error_message)
        """
        # Check if user has opted out
        if user_id in self._opt_outs and feature in self._opt_outs[user_id]:
            return False, None, f"User has opted out of {feature.value}"
        
        # Map feature to data category
        category_map = {
            AIFeature.SYMPTOM_CHECKER: DataCategory.DIAGNOSTICS,
            AIFeature.MENTAL_HEALTH_CHAT: DataCategory.MENTAL_HEALTH,
            AIFeature.DOCUMENT_ANALYSIS: DataCategory.DOCUMENTS,
            AIFeature.HEALTH_INSIGHTS: DataCategory.HEALTH_RECORDS,
            AIFeature.MEDICATION_INTERACTION: DataCategory.MEDICATIONS
        }
        
        result = self.consent_engine.check_consent(ConsentCheck(
            user_id=user_id,
            data_category=category_map.get(feature, DataCategory.PERSONAL_INFO),
            purpose=Purpose.AI_PROCESSING,
            granted_to=GrantedTo.AI_SERVICE
        ))
        
        return result.is_valid, result.consent_id, result.reason
    
    def process_with_governance(
        self,
        request: AIProcessingRequest,
        processor: callable,
        model: AIModel = AIModel.LLAMA_TEXT
    ) -> AIProcessingResult:
        """
        Process AI request with full governance.
        
        1. Check consent
        2. Log the processing
        3. Call the processor
        4. Return with disclaimer
        """
        # Check consent
        is_valid, consent_id, error = self.check_ai_consent(request.user_id, request.feature)
        
        if not is_valid:
            self.audit_logger.log_access_denied(
                user_id=request.user_id,
                resource_type=f"ai_{request.feature.value}",
                reason=error or "AI consent not granted"
            )
            return AIProcessingResult(
                success=False,
                disclaimer=self.get_disclaimer(request.feature),
                error=error or "AI processing consent required. Please enable AI features in settings."
            )
        
        # Log AI processing start
        audit_id = self.audit_logger.log_ai_processing(
            user_id=request.user_id,
            model_used=model.value,
            input_type=request.input_type,
            consent_id=consent_id,
            purpose=request.feature.value,
            details={
                "input_summary": request.input_summary,
                "feature": request.feature.value
            }
        )
        
        try:
            # Call the actual processor
            result = processor()
            
            return AIProcessingResult(
                success=True,
                result=result,
                disclaimer=self.get_disclaimer(request.feature),
                consent_id=consent_id,
                audit_id=audit_id
            )
        except Exception as e:
            return AIProcessingResult(
                success=False,
                disclaimer=self.get_disclaimer(request.feature),
                consent_id=consent_id,
                audit_id=audit_id,
                error=str(e)
            )
    
    def opt_out(self, user_id: str, feature: AIFeature):
        """User opts out of a specific AI feature"""
        if user_id not in self._opt_outs:
            self._opt_outs[user_id] = []
        
        if feature not in self._opt_outs[user_id]:
            self._opt_outs[user_id].append(feature)
        
        self.audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.CONSENT_REVOKED,
            resource_type=f"ai_{feature.value}",
            purpose="ai_opt_out",
            details={"feature": feature.value, "opted_out": True}
        ))
    
    def opt_in(self, user_id: str, feature: AIFeature):
        """User opts back into an AI feature"""
        if user_id in self._opt_outs and feature in self._opt_outs[user_id]:
            self._opt_outs[user_id].remove(feature)
        
        # Also ensure consent is granted
        from .consent import ConsentCreate
        self.consent_engine.grant_consent(ConsentCreate(
            user_id=user_id,
            data_category=self._feature_to_category(feature),
            purpose=Purpose.AI_PROCESSING,
            granted_to=GrantedTo.AI_SERVICE,
            consent_text=f"User opted in to {feature.value} AI processing"
        ))
    
    def get_user_ai_preferences(self, user_id: str) -> Dict[str, bool]:
        """Get user's AI opt-in/out preferences"""
        opted_out = self._opt_outs.get(user_id, [])
        return {
            feature.value: feature not in opted_out
            for feature in AIFeature
        }
    
    def _feature_to_category(self, feature: AIFeature) -> DataCategory:
        """Map AI feature to data category"""
        mapping = {
            AIFeature.SYMPTOM_CHECKER: DataCategory.DIAGNOSTICS,
            AIFeature.MENTAL_HEALTH_CHAT: DataCategory.MENTAL_HEALTH,
            AIFeature.DOCUMENT_ANALYSIS: DataCategory.DOCUMENTS,
            AIFeature.HEALTH_INSIGHTS: DataCategory.HEALTH_RECORDS,
            AIFeature.MEDICATION_INTERACTION: DataCategory.MEDICATIONS
        }
        return mapping.get(feature, DataCategory.PERSONAL_INFO)
    
    @staticmethod
    def wrap_response_with_disclaimer(response: Dict[str, Any], feature: AIFeature) -> Dict[str, Any]:
        """Add AI disclaimer to any response"""
        response["ai_disclaimer"] = DISCLAIMERS[feature]
        response["ai_generated"] = True
        response["ai_generated_at"] = datetime.utcnow().isoformat()
        return response


# Import for backward compatibility
from .audit import AuditLogEntry


# Service-specific governance instances
_governance_instances: Dict[str, AIGovernance] = {}

def get_ai_governance(service_name: str) -> AIGovernance:
    """Get or create AI governance instance for a service"""
    if service_name not in _governance_instances:
        _governance_instances[service_name] = AIGovernance(service_name)
    return _governance_instances[service_name]
