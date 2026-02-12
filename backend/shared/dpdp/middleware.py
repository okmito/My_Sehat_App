"""
DPDP Consent Middleware - Global FastAPI Middleware
=====================================================

This middleware MUST be applied to ALL protected endpoints.
It enforces:
1. Consent validation before data access
2. Purpose-bound access control
3. Audit logging for every request
4. Service-specific DPDP rules

CRITICAL: Without valid consent, ALL requests are BLOCKED with 403.
"""

from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from starlette.middleware.base import BaseHTTPMiddleware
from typing import Optional, Dict, List, Set, Callable
from datetime import datetime
import json
import os
import sys

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from dpdp.consent import ConsentEngine, ConsentCheck, DataCategory, Purpose, GrantedTo
from dpdp.audit import AuditLogger, AuditAction, AuditLogEntry


class DPDPServiceConfig:
    """Service-specific DPDP configuration"""
    
    def __init__(
        self,
        service_name: str,
        service_port: int,
        allowed_categories: Set[DataCategory],
        allowed_purposes: Set[Purpose],
        requires_ai_consent: bool = False,
        session_consent: bool = False,
        anonymous_ids: bool = False,
        auto_expire_hours: Optional[int] = None,
    ):
        self.service_name = service_name
        self.service_port = service_port
        self.allowed_categories = allowed_categories
        self.allowed_purposes = allowed_purposes
        self.requires_ai_consent = requires_ai_consent
        self.session_consent = session_consent
        self.anonymous_ids = anonymous_ids
        self.auto_expire_hours = auto_expire_hours


# Service configurations per port
SERVICE_CONFIGS: Dict[int, DPDPServiceConfig] = {
    # Port 8000 - SOS Emergency
    8000: DPDPServiceConfig(
        service_name="sos_emergency",
        service_port=8000,
        allowed_categories={DataCategory.EMERGENCY, DataCategory.LOCATION, DataCategory.PERSONAL_INFO},
        allowed_purposes={Purpose.EMERGENCY},
        auto_expire_hours=24,  # Emergency consent auto-expires
    ),
    
    # Port 8001 - Diagnostics / Symptom Checker
    8001: DPDPServiceConfig(
        service_name="diagnostics",
        service_port=8001,
        allowed_categories={DataCategory.DIAGNOSTICS, DataCategory.HEALTH_RECORDS},
        allowed_purposes={Purpose.AI_PROCESSING, Purpose.TREATMENT, Purpose.STORAGE},
        requires_ai_consent=True,
    ),
    
    # Port 8002 - Medicine Reminder
    8002: DPDPServiceConfig(
        service_name="medicine",
        service_port=8002,
        allowed_categories={DataCategory.MEDICATIONS},
        allowed_purposes={Purpose.TREATMENT, Purpose.REMINDER, Purpose.STORAGE},
    ),
    
    # Port 8003 - Mental Health
    8003: DPDPServiceConfig(
        service_name="mental_health",
        service_port=8003,
        allowed_categories={DataCategory.MENTAL_HEALTH},
        allowed_purposes={Purpose.AI_PROCESSING, Purpose.STORAGE, Purpose.TREATMENT},
        requires_ai_consent=True,
        session_consent=True,
        anonymous_ids=True,
    ),
    
    # Port 8004 - Health Records
    8004: DPDPServiceConfig(
        service_name="health_records",
        service_port=8004,
        allowed_categories={DataCategory.HEALTH_RECORDS, DataCategory.DOCUMENTS, DataCategory.PERSONAL_INFO},
        allowed_purposes={Purpose.STORAGE, Purpose.EMERGENCY, Purpose.SHARING},
    ),
}


# Endpoints that bypass consent check (public endpoints)
PUBLIC_ENDPOINTS: Set[str] = {
    "/",
    "/docs",
    "/openapi.json",
    "/redoc",
    "/health",
    "/api/health",
    "/api/v1/health",
    # Consent management endpoints (must be accessible to grant consent)
    "/api/v1/consent/grant",
    "/api/v1/consent/revoke",
    "/api/v1/consent/my",
    "/api/v1/consent/check",
    "/consent/grant",
    "/consent/revoke",
    "/consent/my",
    "/consent/check",
    # User rights endpoints
    "/api/v1/my-data",
    "/my-data",
    # Audit log endpoint
    "/api/v1/audit/my",
    "/audit/my",
}


def get_user_id_from_request(request: Request) -> Optional[str]:
    """Extract user ID from request headers or query params"""
    # Try header first
    user_id = request.headers.get("X-User-ID")
    if user_id:
        return user_id
    
    # Try query param
    user_id = request.query_params.get("user_id")
    if user_id:
        return user_id
    
    # Try to get from path (for /users/{user_id}/... routes)
    path_parts = request.url.path.split("/")
    if "users" in path_parts:
        idx = path_parts.index("users")
        if idx + 1 < len(path_parts):
            return path_parts[idx + 1]
    
    # Development mode: use default user
    if os.getenv("DEV_MODE", "false").lower() == "true":
        return "dev_user_001"
    
    return None


def get_data_category_from_endpoint(endpoint: str, service_port: int) -> Optional[DataCategory]:
    """Infer data category from endpoint and service"""
    endpoint_lower = endpoint.lower()
    
    # Service-specific mappings
    if service_port == 8000:  # SOS
        if "location" in endpoint_lower:
            return DataCategory.LOCATION
        return DataCategory.EMERGENCY
    
    elif service_port == 8001:  # Diagnostics
        return DataCategory.DIAGNOSTICS
    
    elif service_port == 8002:  # Medicine
        return DataCategory.MEDICATIONS
    
    elif service_port == 8003:  # Mental Health
        return DataCategory.MENTAL_HEALTH
    
    elif service_port == 8004:  # Health Records
        if "document" in endpoint_lower:
            return DataCategory.DOCUMENTS
        return DataCategory.HEALTH_RECORDS
    
    # Generic mappings
    category_map = {
        "health": DataCategory.HEALTH_RECORDS,
        "record": DataCategory.HEALTH_RECORDS,
        "document": DataCategory.DOCUMENTS,
        "medication": DataCategory.MEDICATIONS,
        "medicine": DataCategory.MEDICATIONS,
        "mental": DataCategory.MENTAL_HEALTH,
        "mood": DataCategory.MENTAL_HEALTH,
        "chat": DataCategory.MENTAL_HEALTH,
        "symptom": DataCategory.DIAGNOSTICS,
        "triage": DataCategory.DIAGNOSTICS,
        "diagnos": DataCategory.DIAGNOSTICS,
        "emergency": DataCategory.EMERGENCY,
        "sos": DataCategory.EMERGENCY,
        "location": DataCategory.LOCATION,
    }
    
    for keyword, category in category_map.items():
        if keyword in endpoint_lower:
            return category
    
    return None


def get_purpose_from_endpoint(endpoint: str, method: str, service_port: int) -> Optional[Purpose]:
    """Infer purpose from endpoint, method, and service"""
    endpoint_lower = endpoint.lower()
    
    # Emergency service always uses EMERGENCY purpose
    if service_port == 8000:
        return Purpose.EMERGENCY
    
    # AI-related endpoints
    if any(kw in endpoint_lower for kw in ["ai", "analyze", "triage", "chat", "inference"]):
        return Purpose.AI_PROCESSING
    
    # Method-based inference
    if method in ["GET"]:
        if "export" in endpoint_lower:
            return Purpose.STORAGE
        return Purpose.TREATMENT
    elif method in ["POST", "PUT", "PATCH"]:
        if "reminder" in endpoint_lower:
            return Purpose.REMINDER
        return Purpose.STORAGE
    
    return Purpose.TREATMENT


class DPDPConsentMiddleware(BaseHTTPMiddleware):
    """
    Global DPDP Consent Middleware
    
    ENFORCES:
    1. Valid consent exists for data category + purpose
    2. Service is allowed to access this data category
    3. Purpose is valid for this service
    4. All access is logged to audit trail
    
    BLOCKS with 403 if:
    - No consent found
    - Consent expired
    - Consent revoked
    - Wrong data category for service
    - Wrong purpose for service
    """
    
    def __init__(self, app, service_port: int = 8000):
        super().__init__(app)
        self.service_port = service_port
        self.config = SERVICE_CONFIGS.get(service_port)
        
        # Initialize consent engine and audit logger
        db_base = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        consent_db = os.path.join(db_base, "consent.db")
        audit_db = os.path.join(db_base, "audit.db")
        
        self.consent_engine = ConsentEngine(f"sqlite:///{consent_db}")
        self.audit_logger = AuditLogger(f"sqlite:///{audit_db}")
    
    async def dispatch(self, request: Request, call_next: Callable):
        endpoint = request.url.path
        method = request.method
        
        # Skip public endpoints
        if self._is_public_endpoint(endpoint):
            return await call_next(request)
        
        # Get user ID
        user_id = get_user_id_from_request(request)
        
        # Determine data category and purpose
        data_category = get_data_category_from_endpoint(endpoint, self.service_port)
        purpose = get_purpose_from_endpoint(endpoint, method, self.service_port)
        
        # Log the attempt regardless of outcome
        ip_address = request.client.host if request.client else None
        
        # DEV_MODE bypass for testing (but still log)
        if os.getenv("DEV_MODE", "false").lower() == "true":
            # Log as allowed in dev mode
            await self._log_access(
                user_id=user_id or "anonymous",
                endpoint=endpoint,
                method=method,
                data_category=data_category,
                purpose=purpose,
                consent_status="dev_mode_allowed",
                success=True,
                ip_address=ip_address,
            )
            return await call_next(request)
        
        # Validate user ID
        if not user_id:
            await self._log_access(
                user_id="anonymous",
                endpoint=endpoint,
                method=method,
                data_category=data_category,
                purpose=purpose,
                consent_status="denied_no_user",
                success=False,
                ip_address=ip_address,
                error="User ID not provided"
            )
            return JSONResponse(
                status_code=status.HTTP_403_FORBIDDEN,
                content={
                    "error": "DPDP_NO_USER_ID",
                    "message": "User identification required for data access",
                    "dpdp_compliant": True
                }
            )
        
        # Validate data category is allowed for this service
        if data_category and self.config:
            if data_category not in self.config.allowed_categories:
                await self._log_access(
                    user_id=user_id,
                    endpoint=endpoint,
                    method=method,
                    data_category=data_category,
                    purpose=purpose,
                    consent_status="denied_wrong_category",
                    success=False,
                    ip_address=ip_address,
                    error=f"Data category {data_category.value} not allowed for service"
                )
                return JSONResponse(
                    status_code=status.HTTP_403_FORBIDDEN,
                    content={
                        "error": "DPDP_CATEGORY_NOT_ALLOWED",
                        "message": f"Service {self.config.service_name} cannot access {data_category.value} data",
                        "dpdp_compliant": True
                    }
                )
        
        # Validate purpose is allowed for this service
        if purpose and self.config:
            if purpose not in self.config.allowed_purposes:
                await self._log_access(
                    user_id=user_id,
                    endpoint=endpoint,
                    method=method,
                    data_category=data_category,
                    purpose=purpose,
                    consent_status="denied_wrong_purpose",
                    success=False,
                    ip_address=ip_address,
                    error=f"Purpose {purpose.value} not allowed for service"
                )
                return JSONResponse(
                    status_code=status.HTTP_403_FORBIDDEN,
                    content={
                        "error": "DPDP_PURPOSE_NOT_ALLOWED",
                        "message": f"Service {self.config.service_name} cannot process data for {purpose.value}",
                        "dpdp_compliant": True
                    }
                )
        
        # Check consent
        if data_category and purpose:
            consent_check = ConsentCheck(
                user_id=user_id,
                data_category=data_category,
                purpose=purpose,
                granted_to=GrantedTo.SELF
            )
            
            result = self.consent_engine.check_consent(consent_check)
            
            if not result.is_valid:
                await self._log_access(
                    user_id=user_id,
                    endpoint=endpoint,
                    method=method,
                    data_category=data_category,
                    purpose=purpose,
                    consent_status="denied_no_consent",
                    success=False,
                    ip_address=ip_address,
                    error=result.reason
                )
                return JSONResponse(
                    status_code=status.HTTP_403_FORBIDDEN,
                    content={
                        "error": "DPDP_CONSENT_REQUIRED",
                        "message": result.reason or "Valid consent required for data access",
                        "data_category": data_category.value,
                        "purpose": purpose.value,
                        "action_required": "Grant consent via /consent/grant endpoint",
                        "dpdp_compliant": True
                    }
                )
            
            # Consent is valid - log and proceed
            await self._log_access(
                user_id=user_id,
                endpoint=endpoint,
                method=method,
                data_category=data_category,
                purpose=purpose,
                consent_status="allowed",
                consent_id=result.consent_id,
                success=True,
                ip_address=ip_address,
            )
        
        # Proceed with request
        response = await call_next(request)
        return response
    
    def _is_public_endpoint(self, endpoint: str) -> bool:
        """Check if endpoint is public (no consent required)"""
        # Exact match
        if endpoint in PUBLIC_ENDPOINTS:
            return True
        
        # Prefix match for API versions
        for public in PUBLIC_ENDPOINTS:
            if endpoint.startswith(public) or endpoint.endswith(public):
                return True
        
        return False
    
    async def _log_access(
        self,
        user_id: str,
        endpoint: str,
        method: str,
        data_category: Optional[DataCategory],
        purpose: Optional[Purpose],
        consent_status: str,
        success: bool,
        ip_address: Optional[str] = None,
        consent_id: Optional[int] = None,
        error: Optional[str] = None,
    ):
        """Log access attempt to audit trail"""
        try:
            action = AuditAction.READ if method == "GET" else AuditAction.WRITE
            if not success:
                action = AuditAction.ACCESS_DENIED
            
            entry = AuditLogEntry(
                user_id=user_id,
                action=action,
                resource_type=data_category.value if data_category else "unknown",
                resource_id=endpoint,
                purpose=purpose.value if purpose else None,
                consent_id=consent_id,
                details={
                    "method": method,
                    "endpoint": endpoint,
                    "consent_status": consent_status,
                    "service_port": self.service_port,
                    "service_name": self.config.service_name if self.config else "unknown",
                },
                data_categories=[data_category.value] if data_category else [],
                ip_address=ip_address,
                service_name=self.config.service_name if self.config else "unknown",
                success=success,
                error_message=error,
            )
            
            self.audit_logger.log(entry)
        except Exception as e:
            # Don't fail request if logging fails, but print error
            print(f"[DPDP] Audit log error: {e}")


def create_dpdp_middleware(service_port: int):
    """Factory function to create DPDP middleware for a specific service"""
    def middleware_factory(app):
        return DPDPConsentMiddleware(app, service_port=service_port)
    return middleware_factory


# Convenience function to add middleware to FastAPI app
def add_dpdp_middleware(app, service_port: int):
    """Add DPDP consent middleware to FastAPI app"""
    app.add_middleware(DPDPConsentMiddleware, service_port=service_port)
    return app
