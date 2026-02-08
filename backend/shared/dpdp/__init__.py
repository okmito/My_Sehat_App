"""
DPDP Act 2023 Compliance Module for MySehat Platform
=====================================================

This module implements Digital Personal Data Protection Act compliance
as first-class system features enforced at the architecture level.

"MySehat is not just privacy-aware — it is DPDP-native, where legal compliance,
ethical AI, and user data ownership are enforced directly at the system architecture level."
"""

from .consent import (
    ConsentEngine, 
    ConsentCheck, 
    ConsentCreate,
    ConsentCheckResult,
    ConsentResponse,
    ConsentRecord,
    DataCategory, 
    Purpose, 
    GrantedTo,
    ConsentStatus,
    get_consent_engine
)
from .audit import (
    AuditLogger, 
    AuditAction,
    AuditLog,
    AuditLogEntry,
    get_audit_logger
)
from .user_rights import (
    UserRightsManager,
    DeletionRequest,
    DeletionStatus,
    CorrectionRequest,
    get_user_rights_manager
)
from .ai_governance import (
    AIGovernance,
    AIFeature,
    AIModel,
    AIProcessingRequest,
    AIProcessingResult,
    DISCLAIMERS,
    get_ai_governance
)
from .emergency_data import (
    EmergencyDataField,
    RestrictedDataField,
    EmergencyDataPacket,
    EmergencyAccessConfig,
    get_emergency_data_packet,
    DEFAULT_EMERGENCY_CONFIG
)
from .middleware import (
    DPDPConsentMiddleware,
    DPDPServiceConfig,
    SERVICE_CONFIGS,
    add_dpdp_middleware,
    create_dpdp_middleware,
)
from .api_router import (
    create_consent_router,
    create_user_rights_router,
    create_audit_router,
)

__all__ = [
    # Consent
    'ConsentEngine',
    'ConsentCheck', 
    'ConsentCreate',
    'ConsentCheckResult',
    'ConsentResponse',
    'ConsentRecord',
    'ConsentStatus',
    'DataCategory',
    'Purpose',
    'GrantedTo',
    'get_consent_engine',
    
    # Audit
    'AuditLogger',
    'AuditAction',
    'AuditLog',
    'AuditLogEntry',
    'get_audit_logger',
    
    # User Rights
    'UserRightsManager',
    'DeletionRequest',
    'DeletionStatus',
    'CorrectionRequest',
    'get_user_rights_manager',
    
    # AI Governance
    'AIGovernance',
    'AIFeature',
    'AIModel',
    'AIProcessingRequest',
    'AIProcessingResult',
    'DISCLAIMERS',
    'get_ai_governance',
    
    # Emergency Data
    'EmergencyDataField',
    'RestrictedDataField',
    'EmergencyDataPacket',
    'EmergencyAccessConfig',
    'get_emergency_data_packet',
    'DEFAULT_EMERGENCY_CONFIG',
    
    # Middleware
    'DPDPConsentMiddleware',
    'DPDPServiceConfig',
    'SERVICE_CONFIGS',
    'add_dpdp_middleware',
    'create_dpdp_middleware',
    
    # API Routers
    'create_consent_router',
    'create_user_rights_router',
    'create_audit_router',
]
