"""
DPDP Consent API Router - REST APIs for Consent Management
============================================================

Provides endpoints for:
1. Granting consent
2. Revoking consent  
3. Viewing active consents
4. Checking consent status

These endpoints are PUBLIC (no consent check required to access them).
"""

from fastapi import APIRouter, HTTPException, Header, Query, Request, status
from typing import Optional, List
from datetime import datetime, timedelta
from pydantic import BaseModel, Field
import os
import sys

# Add parent directory for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dpdp.consent import (
    ConsentEngine, ConsentCreate, ConsentResponse, ConsentCheck, ConsentCheckResult,
    DataCategory, Purpose, GrantedTo
)
from dpdp.audit import AuditLogger, AuditAction, AuditLogEntry


# Pydantic models for API
class GrantConsentRequest(BaseModel):
    """Request to grant consent"""
    data_category: str = Field(..., description="Category of data: location, mental_health, documents, medications, diagnostics, emergency, health_records, personal_info")
    purpose: str = Field(..., description="Purpose: emergency, treatment, storage, ai_processing, reminder, analytics, sharing")
    granted_to: str = Field(default="self", description="Who receives access: self, hospital, ambulance, ai_service, emergency_responder, healthcare_worker")
    expires_in_days: Optional[int] = Field(default=None, description="Days until consent expires. None = no expiry")
    consent_text: Optional[str] = Field(default=None, description="Description of what user is consenting to")


class RevokeConsentRequest(BaseModel):
    """Request to revoke consent"""
    data_category: Optional[str] = Field(default=None, description="Category to revoke. None = revoke all")
    purpose: Optional[str] = Field(default=None, description="Purpose to revoke. None = revoke all for category")


class CheckConsentRequest(BaseModel):
    """Request to check consent status"""
    data_category: str
    purpose: str
    granted_to: str = "self"


class ConsentStatusResponse(BaseModel):
    """Response for consent status"""
    has_consent: bool
    consent_id: Optional[int] = None
    reason: Optional[str] = None
    expires_at: Optional[datetime] = None
    data_category: str
    purpose: str


class ConsentListResponse(BaseModel):
    """Response for listing consents"""
    consents: List[ConsentResponse]
    total: int
    active_count: int
    revoked_count: int
    expired_count: int


def create_consent_router(service_name: str = "default") -> APIRouter:
    """
    Create consent management router for a service.
    
    These endpoints allow users to:
    - Grant consent for specific data categories and purposes
    - Revoke consent at any time
    - View all their consent records
    - Check if specific consent exists
    """
    
    router = APIRouter(prefix="/consent", tags=["DPDP Consent Management"])
    
    # Initialize engines
    db_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    consent_db = os.path.join(db_base, "consent.db")
    audit_db = os.path.join(db_base, "audit.db")
    
    consent_engine = ConsentEngine(f"sqlite:///{consent_db}")
    audit_logger = AuditLogger(f"sqlite:///{audit_db}")
    
    @router.post("/grant", response_model=ConsentResponse)
    async def grant_consent(
        request: GrantConsentRequest,
        user_id: str = Header(..., alias="X-User-ID", description="User ID from header"),
        ip_address: Optional[str] = Header(None, alias="X-Forwarded-For"),
    ):
        """
        Grant explicit consent for data processing.
        
        DPDP Requirement: Consent must be:
        - Freely given
        - Specific to purpose
        - Informed
        - Unambiguous
        """
        try:
            # Validate data category
            try:
                category = DataCategory(request.data_category)
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid data_category. Must be one of: {[c.value for c in DataCategory]}"
                )
            
            # Validate purpose
            try:
                purpose = Purpose(request.purpose)
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid purpose. Must be one of: {[p.value for p in Purpose]}"
                )
            
            # Validate granted_to
            try:
                granted_to = GrantedTo(request.granted_to)
            except ValueError:
                raise HTTPException(
                    status_code=400,
                    detail=f"Invalid granted_to. Must be one of: {[g.value for g in GrantedTo]}"
                )
            
            # Create consent
            consent_create = ConsentCreate(
                user_id=user_id,
                data_category=category,
                purpose=purpose,
                granted_to=granted_to,
                expires_in_days=request.expires_in_days,
                consent_text=request.consent_text,
                ip_address=ip_address,
            )
            
            result = consent_engine.grant_consent(consent_create)
            
            # Log consent grant
            audit_logger.log(AuditLogEntry(
                user_id=user_id,
                action=AuditAction.CONSENT_GRANTED,
                resource_type="consent",
                resource_id=str(result.id),
                purpose=purpose.value,
                consent_id=result.id,
                details={
                    "data_category": category.value,
                    "granted_to": granted_to.value,
                    "expires_in_days": request.expires_in_days,
                },
                ip_address=ip_address,
                service_name=service_name,
                success=True,
            ))
            
            return result
            
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @router.post("/revoke")
    async def revoke_consent(
        request: RevokeConsentRequest,
        user_id: str = Header(..., alias="X-User-ID"),
        ip_address: Optional[str] = Header(None, alias="X-Forwarded-For"),
    ):
        """
        Revoke consent. Takes effect IMMEDIATELY.
        
        DPDP Requirement: Users can withdraw consent at any time.
        Withdrawal does not affect lawfulness of prior processing.
        """
        try:
            category = None
            purpose = None
            
            if request.data_category:
                try:
                    category = DataCategory(request.data_category)
                except ValueError:
                    raise HTTPException(status_code=400, detail="Invalid data_category")
            
            if request.purpose:
                try:
                    purpose = Purpose(request.purpose)
                except ValueError:
                    raise HTTPException(status_code=400, detail="Invalid purpose")
            
            count = consent_engine.revoke_consent(
                user_id=user_id,
                data_category=category,
                purpose=purpose
            )
            
            # Log revocation
            audit_logger.log(AuditLogEntry(
                user_id=user_id,
                action=AuditAction.CONSENT_REVOKED,
                resource_type="consent",
                purpose=purpose.value if purpose else "all",
                details={
                    "data_category": category.value if category else "all",
                    "consents_revoked": count,
                },
                ip_address=ip_address,
                service_name=service_name,
                success=True,
            ))
            
            return {
                "message": f"Successfully revoked {count} consent(s)",
                "consents_revoked": count,
                "effective_immediately": True,
                "dpdp_compliant": True
            }
            
        except HTTPException:
            raise
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @router.get("/my", response_model=ConsentListResponse)
    async def get_my_consents(
        user_id: str = Header(..., alias="X-User-ID"),
    ):
        """
        View all consent records for the user.
        
        DPDP Requirement: Right to access information about consent.
        """
        try:
            consents = consent_engine.get_user_consents(user_id)
            
            active = sum(1 for c in consents if c.status == "active")
            revoked = sum(1 for c in consents if c.status == "revoked")
            expired = sum(1 for c in consents if c.status == "expired")
            
            return ConsentListResponse(
                consents=consents,
                total=len(consents),
                active_count=active,
                revoked_count=revoked,
                expired_count=expired,
            )
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @router.post("/check", response_model=ConsentStatusResponse)
    async def check_consent_status(
        request: CheckConsentRequest,
        user_id: str = Header(..., alias="X-User-ID"),
    ):
        """
        Check if specific consent is valid.
        
        Use this to verify consent before showing feature UI.
        """
        try:
            category = DataCategory(request.data_category)
            purpose = Purpose(request.purpose)
            granted_to = GrantedTo(request.granted_to)
            
            check = ConsentCheck(
                user_id=user_id,
                data_category=category,
                purpose=purpose,
                granted_to=granted_to
            )
            
            result = consent_engine.check_consent(check)
            
            return ConsentStatusResponse(
                has_consent=result.is_valid,
                consent_id=result.consent_id,
                reason=result.reason,
                expires_at=result.expires_at,
                data_category=request.data_category,
                purpose=request.purpose,
            )
            
        except ValueError as e:
            raise HTTPException(status_code=400, detail=str(e))
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    return router


def create_user_rights_router(service_name: str = "default") -> APIRouter:
    """
    Create user rights router for DPDP compliance.
    
    Implements:
    - Right to Access (GET /my-data)
    - Right to Erasure (DELETE /my-data)
    - Right to Correction (PATCH /my-data)
    """
    
    router = APIRouter(prefix="/my-data", tags=["DPDP User Rights"])
    
    db_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audit_db = os.path.join(db_base, "audit.db")
    consent_db = os.path.join(db_base, "consent.db")
    
    audit_logger = AuditLogger(f"sqlite:///{audit_db}")
    consent_engine = ConsentEngine(f"sqlite:///{consent_db}")
    
    @router.get("")
    async def export_my_data(
        user_id: str = Header(..., alias="X-User-ID"),
        ip_address: Optional[str] = Header(None, alias="X-Forwarded-For"),
    ):
        """
        Export all user data (Right to Access / Portability).
        
        DPDP Requirement: Users can request copy of all their personal data.
        """
        try:
            # Get consents
            consents = consent_engine.get_user_consents(user_id)
            
            # Get audit logs
            audit_logs = audit_logger.get_user_logs(user_id, limit=100)
            
            # Log the export request
            audit_logger.log(AuditLogEntry(
                user_id=user_id,
                action=AuditAction.DATA_EXPORT,
                resource_type="all_data",
                details={"export_type": "full"},
                ip_address=ip_address,
                service_name=service_name,
                success=True,
            ))
            
            return {
                "user_id": user_id,
                "export_date": datetime.utcnow().isoformat(),
                "dpdp_compliance": "Right to Access / Data Portability",
                "data": {
                    "consents": [c.model_dump() for c in consents],
                    "audit_logs": [a.model_dump() for a in audit_logs],
                },
                "notice": "This export includes consent records and audit logs. Service-specific data must be requested from each service."
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @router.delete("")
    async def delete_my_data(
        user_id: str = Header(..., alias="X-User-ID"),
        confirm: bool = Query(False, description="Set to true to confirm deletion"),
        ip_address: Optional[str] = Header(None, alias="X-Forwarded-For"),
    ):
        """
        Delete all user data (Right to Erasure).
        
        DPDP Requirement: Users can request deletion of their personal data.
        Subject to legal retention requirements.
        """
        if not confirm:
            return {
                "warning": "Data deletion is irreversible",
                "action_required": "Set confirm=true to proceed",
                "grace_period": "30 days before permanent deletion",
                "exceptions": "Some data may be retained for legal compliance"
            }
        
        try:
            # Revoke all consents
            revoked = consent_engine.revoke_consent(user_id)
            
            # Log erasure request
            audit_logger.log(AuditLogEntry(
                user_id=user_id,
                action=AuditAction.DATA_ERASURE,
                resource_type="all_data",
                details={
                    "consents_revoked": revoked,
                    "status": "initiated",
                    "grace_period_days": 30,
                },
                ip_address=ip_address,
                service_name=service_name,
                success=True,
            ))
            
            return {
                "status": "deletion_initiated",
                "consents_revoked": revoked,
                "grace_period": "30 days",
                "completion_date": (datetime.utcnow() + timedelta(days=30)).isoformat(),
                "dpdp_compliance": "Right to Erasure initiated",
                "notice": "You can cancel deletion within 30 days by granting new consent"
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    @router.patch("")
    async def correct_my_data(
        user_id: str = Header(..., alias="X-User-ID"),
        ip_address: Optional[str] = Header(None, alias="X-Forwarded-For"),
    ):
        """
        Request data correction (Right to Correction).
        
        DPDP Requirement: Users can request correction of inaccurate data.
        """
        # Log correction request
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_CORRECTION,
            resource_type="correction_request",
            details={"status": "received"},
            ip_address=ip_address,
            service_name=service_name,
            success=True,
        ))
        
        return {
            "status": "correction_request_received",
            "ticket_id": f"CORR-{user_id[:8]}-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}",
            "response_time": "Within 30 days as per DPDP Act",
            "dpdp_compliance": "Right to Correction"
        }
    
    return router


def create_audit_router(service_name: str = "default") -> APIRouter:
    """
    Create audit log viewing router.
    
    Allows users to see their data access history.
    """
    
    router = APIRouter(prefix="/audit", tags=["DPDP Audit Trail"])
    
    db_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    audit_db = os.path.join(db_base, "audit.db")
    
    audit_logger = AuditLogger(f"sqlite:///{audit_db}")
    
    @router.get("/my")
    async def get_my_audit_logs(
        user_id: str = Header(..., alias="X-User-ID"),
        limit: int = Query(50, ge=1, le=500),
        action: Optional[str] = Query(None, description="Filter by action type"),
    ):
        """
        View audit trail of data access.
        
        DPDP Requirement: Transparency about data processing.
        """
        try:
            logs = audit_logger.get_user_logs(
                user_id=user_id,
                limit=limit,
                action_filter=action
            )
            
            return {
                "user_id": user_id,
                "logs": [log.model_dump() for log in logs],
                "total": len(logs),
                "dpdp_compliance": "Data Access Transparency"
            }
            
        except Exception as e:
            raise HTTPException(status_code=500, detail=str(e))
    
    return router
