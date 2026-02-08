"""
Audit Logging System - DPDP Act 2023 Compliance
================================================

Every data access MUST be logged with:
- Who accessed
- What data
- For what purpose
- Under which consent
- At what time

Provides accountability and traceability for regulatory compliance.
"""

from enum import Enum
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, create_engine, JSON
from sqlalchemy.orm import sessionmaker, declarative_base
import json
import os

Base = declarative_base()


class AuditAction(str, Enum):
    """Types of auditable actions"""
    # Data Access
    READ = "read"
    WRITE = "write"
    UPDATE = "update"
    DELETE = "delete"
    
    # Consent
    CONSENT_GRANTED = "consent_granted"
    CONSENT_REVOKED = "consent_revoked"
    CONSENT_EXPIRED = "consent_expired"
    CONSENT_CHECK = "consent_check"
    
    # AI Processing
    AI_ANALYSIS = "ai_analysis"
    AI_INFERENCE = "ai_inference"
    
    # Emergency
    EMERGENCY_ACCESS = "emergency_access"
    EMERGENCY_OVERRIDE = "emergency_override"
    
    # User Rights
    DATA_EXPORT = "data_export"
    DATA_ERASURE = "data_erasure"
    DATA_CORRECTION = "data_correction"
    
    # Authentication
    LOGIN = "login"
    LOGOUT = "logout"
    
    # Sharing
    DATA_SHARED = "data_shared"
    ACCESS_DENIED = "access_denied"


class AuditLog(Base):
    """SQLAlchemy model for audit logs"""
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    
    # Who
    user_id = Column(String(100), nullable=False, index=True)
    actor_id = Column(String(100), nullable=True)  # Who performed action (if different from user)
    actor_type = Column(String(50), nullable=True)  # user, system, ai_service, emergency_responder
    
    # What
    action = Column(String(50), nullable=False, index=True)
    resource_type = Column(String(50), nullable=False)  # health_record, medication, chat, etc.
    resource_id = Column(String(100), nullable=True)
    
    # Purpose & Consent
    purpose = Column(String(50), nullable=True)
    consent_id = Column(Integer, nullable=True)
    
    # Details
    details = Column(Text, nullable=True)  # JSON string with additional context
    data_categories = Column(String(200), nullable=True)  # Comma-separated categories accessed
    
    # Context
    ip_address = Column(String(50), nullable=True)
    device_info = Column(String(200), nullable=True)
    service_name = Column(String(50), nullable=True)  # Which microservice
    
    # Result
    success = Column(Boolean, default=True)
    error_message = Column(Text, nullable=True)
    
    # Timestamp
    timestamp = Column(DateTime, default=datetime.utcnow, index=True)
    
    # For emergency audit
    justification = Column(Text, nullable=True)
    emergency_id = Column(String(100), nullable=True)


class AuditLogEntry(BaseModel):
    """Schema for creating audit log entries"""
    user_id: str
    action: AuditAction
    resource_type: str
    resource_id: Optional[str] = None
    actor_id: Optional[str] = None
    actor_type: Optional[str] = "user"
    purpose: Optional[str] = None
    consent_id: Optional[int] = None
    details: Optional[Dict[str, Any]] = None
    data_categories: Optional[List[str]] = None
    ip_address: Optional[str] = None
    device_info: Optional[str] = None
    service_name: Optional[str] = None
    success: bool = True
    error_message: Optional[str] = None
    justification: Optional[str] = None
    emergency_id: Optional[str] = None


class AuditLogResponse(BaseModel):
    """Schema for audit log response"""
    id: int
    user_id: str
    action: str
    resource_type: str
    resource_id: Optional[str]
    purpose: Optional[str]
    timestamp: datetime
    success: bool
    
    class Config:
        from_attributes = True


class AuditLogger:
    """
    Centralized audit logging for DPDP compliance.
    
    Every service MUST log:
    - All data access (read/write/update/delete)
    - Consent operations
    - AI processing
    - Emergency access with justification
    - User rights exercised
    """
    
    def __init__(self, db_url: str = None, service_name: str = "default"):
        self.service_name = service_name
        
        # Detect Render environment for database path
        if db_url is None:
            render_env = os.environ.get("RENDER", None)
            if render_env or os.environ.get("PORT"):
                # On Render, use /tmp for writable storage
                db_path = "/tmp/audit.db"
            else:
                # Local development
                db_path = os.path.join(os.path.dirname(__file__), "..", "..", "audit.db")
            db_url = f"sqlite:///{db_path}"
        
        self.engine = create_engine(db_url, echo=False)
        
        # Handle concurrent table creation (multiple backends starting simultaneously)
        try:
            Base.metadata.create_all(self.engine, checkfirst=True)
        except Exception as e:
            # Ignore "table already exists" errors from concurrent creation
            if "already exists" not in str(e).lower():
                print(f"⚠️  Warning: Audit logger initialization issue: {e}")
        
        self.Session = sessionmaker(bind=self.engine)
    
    def log(self, entry: AuditLogEntry) -> int:
        """
        Log an auditable action.
        Returns the audit log ID for reference.
        """
        session = self.Session()
        try:
            record = AuditLog(
                user_id=entry.user_id,
                actor_id=entry.actor_id,
                actor_type=entry.actor_type,
                action=entry.action.value,
                resource_type=entry.resource_type,
                resource_id=entry.resource_id,
                purpose=entry.purpose,
                consent_id=entry.consent_id,
                details=json.dumps(entry.details) if entry.details else None,
                data_categories=",".join(entry.data_categories) if entry.data_categories else None,
                ip_address=entry.ip_address,
                device_info=entry.device_info,
                service_name=entry.service_name or self.service_name,
                success=entry.success,
                error_message=entry.error_message,
                justification=entry.justification,
                emergency_id=entry.emergency_id
            )
            
            session.add(record)
            session.commit()
            return record.id
        finally:
            session.close()
    
    def log_data_access(
        self,
        user_id: str,
        action: AuditAction,
        resource_type: str,
        resource_id: str = None,
        consent_id: int = None,
        purpose: str = None,
        data_categories: List[str] = None,
        details: Dict[str, Any] = None
    ) -> int:
        """Convenience method for logging data access"""
        return self.log(AuditLogEntry(
            user_id=user_id,
            action=action,
            resource_type=resource_type,
            resource_id=resource_id,
            consent_id=consent_id,
            purpose=purpose,
            data_categories=data_categories,
            details=details,
            service_name=self.service_name
        ))
    
    def log_emergency_access(
        self,
        user_id: str,
        emergency_id: str,
        responder_id: str,
        data_accessed: List[str],
        justification: str
    ) -> int:
        """
        Log emergency data access with justification.
        REQUIRED for every emergency override.
        """
        return self.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.EMERGENCY_ACCESS,
            resource_type="emergency_data",
            actor_id=responder_id,
            actor_type="emergency_responder",
            purpose="emergency",
            data_categories=data_accessed,
            justification=justification,
            emergency_id=emergency_id,
            details={
                "emergency_id": emergency_id,
                "data_fields_accessed": data_accessed,
                "access_justification": justification
            },
            service_name=self.service_name
        ))
    
    def log_ai_processing(
        self,
        user_id: str,
        model_used: str,
        input_type: str,
        consent_id: int,
        purpose: str,
        details: Dict[str, Any] = None
    ) -> int:
        """Log AI processing for transparency"""
        return self.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.AI_ANALYSIS,
            resource_type="ai_processing",
            purpose=purpose,
            consent_id=consent_id,
            details={
                "model_used": model_used,
                "input_type": input_type,
                **(details or {})
            },
            service_name=self.service_name
        ))
    
    def log_consent_operation(
        self,
        user_id: str,
        action: AuditAction,
        consent_id: int,
        data_category: str,
        purpose: str
    ) -> int:
        """Log consent operations"""
        return self.log(AuditLogEntry(
            user_id=user_id,
            action=action,
            resource_type="consent",
            resource_id=str(consent_id),
            purpose=purpose,
            data_categories=[data_category],
            service_name=self.service_name
        ))
    
    def log_access_denied(
        self,
        user_id: str,
        resource_type: str,
        reason: str
    ) -> int:
        """Log access denial for audit trail"""
        return self.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.ACCESS_DENIED,
            resource_type=resource_type,
            success=False,
            error_message=reason,
            service_name=self.service_name
        ))
    
    def get_user_audit_trail(
        self,
        user_id: str,
        start_date: datetime = None,
        end_date: datetime = None,
        action_filter: AuditAction = None,
        limit: int = 100
    ) -> List[AuditLogResponse]:
        """Get audit trail for a user (for transparency/export)"""
        session = self.Session()
        try:
            query = session.query(AuditLog).filter(AuditLog.user_id == user_id)
            
            if start_date:
                query = query.filter(AuditLog.timestamp >= start_date)
            if end_date:
                query = query.filter(AuditLog.timestamp <= end_date)
            if action_filter:
                query = query.filter(AuditLog.action == action_filter.value)
            
            records = query.order_by(AuditLog.timestamp.desc()).limit(limit).all()
            return [AuditLogResponse.model_validate(r) for r in records]
        finally:
            session.close()
    
    def get_user_logs(
        self,
        user_id: str,
        limit: int = 100,
        action_filter: str = None
    ) -> List[AuditLogResponse]:
        """Get audit logs for a user (alias for get_user_audit_trail)"""
        af = None
        if action_filter:
            try:
                af = AuditAction(action_filter)
            except ValueError:
                pass
        return self.get_user_audit_trail(user_id=user_id, action_filter=af, limit=limit)
    
    def get_emergency_audit(
        self,
        emergency_id: str
    ) -> List[AuditLogResponse]:
        """Get all audit logs for a specific emergency"""
        session = self.Session()
        try:
            records = session.query(AuditLog).filter(
                AuditLog.emergency_id == emergency_id
            ).order_by(AuditLog.timestamp.asc()).all()
            
            return [AuditLogResponse.model_validate(r) for r in records]
        finally:
            session.close()
    
    def export_audit_logs(
        self,
        start_date: datetime,
        end_date: datetime,
        service_filter: str = None
    ) -> List[Dict[str, Any]]:
        """Export audit logs for regulatory reporting"""
        session = self.Session()
        try:
            query = session.query(AuditLog).filter(
                AuditLog.timestamp >= start_date,
                AuditLog.timestamp <= end_date
            )
            
            if service_filter:
                query = query.filter(AuditLog.service_name == service_filter)
            
            records = query.order_by(AuditLog.timestamp.asc()).all()
            
            return [
                {
                    "id": r.id,
                    "user_id": r.user_id,
                    "actor_id": r.actor_id,
                    "action": r.action,
                    "resource_type": r.resource_type,
                    "resource_id": r.resource_id,
                    "purpose": r.purpose,
                    "consent_id": r.consent_id,
                    "data_categories": r.data_categories,
                    "service_name": r.service_name,
                    "success": r.success,
                    "error_message": r.error_message,
                    "justification": r.justification,
                    "timestamp": r.timestamp.isoformat()
                }
                for r in records
            ]
        finally:
            session.close()


# Service-specific loggers
_loggers: Dict[str, AuditLogger] = {}

def get_audit_logger(service_name: str) -> AuditLogger:
    """Get or create audit logger for a service"""
    if service_name not in _loggers:
        _loggers[service_name] = AuditLogger(service_name=service_name)
    return _loggers[service_name]
