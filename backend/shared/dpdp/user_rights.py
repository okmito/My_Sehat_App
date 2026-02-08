"""
User Rights Module - DPDP Act 2023 Compliance
==============================================

Implements user rights under DPDP Act:
- Right to Access (GET /my-data)
- Right to Correction (PATCH /my-data)
- Right to Erasure (DELETE /my-data)

With proper cascading across all services.
"""

from enum import Enum
from datetime import datetime, timedelta
from typing import Optional, List, Dict, Any
from pydantic import BaseModel
from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os

Base = declarative_base()


class DeletionStatus(str, Enum):
    """Status of deletion request"""
    PENDING = "pending"           # In grace period
    PROCESSING = "processing"     # Being deleted
    COMPLETED = "completed"       # Fully deleted
    CANCELLED = "cancelled"       # User cancelled during grace period


class DeletionRequest(Base):
    """SQLAlchemy model for deletion requests"""
    __tablename__ = "deletion_requests"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    
    # Scope of deletion
    delete_all = Column(Boolean, default=False)
    services = Column(Text, nullable=True)  # Comma-separated list of services
    data_categories = Column(Text, nullable=True)  # Comma-separated categories
    
    # Status
    status = Column(String(20), default=DeletionStatus.PENDING.value)
    
    # Timing
    requested_at = Column(DateTime, default=datetime.utcnow)
    grace_period_ends = Column(DateTime, nullable=True)  # 7-day grace period
    completed_at = Column(DateTime, nullable=True)
    
    # Audit
    reason = Column(Text, nullable=True)
    ip_address = Column(String(50), nullable=True)


class DataExportRequest(Base):
    """SQLAlchemy model for data export requests"""
    __tablename__ = "data_export_requests"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    
    # Status
    status = Column(String(20), default="pending")
    
    # Timing
    requested_at = Column(DateTime, default=datetime.utcnow)
    completed_at = Column(DateTime, nullable=True)
    expires_at = Column(DateTime, nullable=True)  # Export link expires
    
    # Result
    export_path = Column(String(500), nullable=True)
    export_format = Column(String(20), default="json")


# Pydantic Schemas
class ErasureRequest(BaseModel):
    """Schema for data erasure request"""
    user_id: str
    delete_all: bool = False
    services: Optional[List[str]] = None  # Specific services to delete from
    data_categories: Optional[List[str]] = None  # Specific categories
    reason: Optional[str] = None
    ip_address: Optional[str] = None


class ErasureResponse(BaseModel):
    """Response for erasure request"""
    request_id: int
    status: str
    grace_period_ends: datetime
    message: str
    can_cancel_until: datetime


class CorrectionRequest(BaseModel):
    """Schema for data correction request"""
    user_id: str
    resource_type: str
    resource_id: str
    field_name: str
    current_value: Optional[str] = None
    corrected_value: str
    reason: Optional[str] = None


class UserDataExport(BaseModel):
    """Schema for exported user data"""
    user_id: str
    export_date: datetime
    services: Dict[str, Any]
    consents: List[Dict[str, Any]]
    audit_trail: List[Dict[str, Any]]


class UserRightsManager:
    """
    Manages user rights under DPDP Act.
    
    Implements:
    - Right to Access: Export all personal data
    - Right to Correction: Fix incorrect data
    - Right to Erasure: Delete personal data (with grace period)
    """
    
    GRACE_PERIOD_DAYS = 7
    
    def __init__(self, db_url: str = None):
        if db_url is None:
            db_path = os.path.join(os.path.dirname(__file__), "..", "..", "user_rights.db")
            db_url = f"sqlite:///{db_path}"
        
        self.engine = create_engine(db_url, echo=False)
        Base.metadata.create_all(self.engine, checkfirst=True)
        self.Session = sessionmaker(bind=self.engine)
        
        # Service callbacks for cascading operations
        self._deletion_handlers: Dict[str, callable] = {}
        self._export_handlers: Dict[str, callable] = {}
        self._correction_handlers: Dict[str, callable] = {}
    
    def register_deletion_handler(self, service_name: str, handler: callable):
        """Register a handler for deleting data from a service"""
        self._deletion_handlers[service_name] = handler
    
    def register_export_handler(self, service_name: str, handler: callable):
        """Register a handler for exporting data from a service"""
        self._export_handlers[service_name] = handler
    
    def register_correction_handler(self, service_name: str, handler: callable):
        """Register a handler for correcting data in a service"""
        self._correction_handlers[service_name] = handler
    
    def request_erasure(self, request: ErasureRequest) -> ErasureResponse:
        """
        Request data erasure (Right to Erasure).
        
        Implements soft-delete with grace period, then hard delete.
        """
        session = self.Session()
        try:
            # Check for existing pending request
            existing = session.query(DeletionRequest).filter(
                DeletionRequest.user_id == request.user_id,
                DeletionRequest.status == DeletionStatus.PENDING.value
            ).first()
            
            if existing:
                return ErasureResponse(
                    request_id=existing.id,
                    status=existing.status,
                    grace_period_ends=existing.grace_period_ends,
                    message="Existing deletion request found",
                    can_cancel_until=existing.grace_period_ends
                )
            
            grace_end = datetime.utcnow() + timedelta(days=self.GRACE_PERIOD_DAYS)
            
            deletion_req = DeletionRequest(
                user_id=request.user_id,
                delete_all=request.delete_all,
                services=",".join(request.services) if request.services else None,
                data_categories=",".join(request.data_categories) if request.data_categories else None,
                reason=request.reason,
                ip_address=request.ip_address,
                grace_period_ends=grace_end,
                status=DeletionStatus.PENDING.value
            )
            
            session.add(deletion_req)
            session.commit()
            session.refresh(deletion_req)
            
            return ErasureResponse(
                request_id=deletion_req.id,
                status=DeletionStatus.PENDING.value,
                grace_period_ends=grace_end,
                message=f"Deletion scheduled. You have {self.GRACE_PERIOD_DAYS} days to cancel.",
                can_cancel_until=grace_end
            )
        finally:
            session.close()
    
    def cancel_erasure(self, user_id: str, request_id: int) -> bool:
        """Cancel a pending erasure request during grace period"""
        session = self.Session()
        try:
            request = session.query(DeletionRequest).filter(
                DeletionRequest.id == request_id,
                DeletionRequest.user_id == user_id,
                DeletionRequest.status == DeletionStatus.PENDING.value
            ).first()
            
            if not request:
                return False
            
            if request.grace_period_ends < datetime.utcnow():
                return False  # Grace period ended
            
            request.status = DeletionStatus.CANCELLED.value
            session.commit()
            return True
        finally:
            session.close()
    
    def process_pending_deletions(self):
        """
        Process deletions that have passed grace period.
        Should be run as a scheduled job.
        """
        session = self.Session()
        try:
            pending = session.query(DeletionRequest).filter(
                DeletionRequest.status == DeletionStatus.PENDING.value,
                DeletionRequest.grace_period_ends <= datetime.utcnow()
            ).all()
            
            for request in pending:
                request.status = DeletionStatus.PROCESSING.value
                session.commit()
                
                try:
                    # Determine which services to delete from
                    services = (
                        request.services.split(",") if request.services 
                        else list(self._deletion_handlers.keys())
                    )
                    
                    # Call deletion handlers
                    for service in services:
                        if service in self._deletion_handlers:
                            self._deletion_handlers[service](
                                user_id=request.user_id,
                                categories=request.data_categories.split(",") if request.data_categories else None
                            )
                    
                    request.status = DeletionStatus.COMPLETED.value
                    request.completed_at = datetime.utcnow()
                    
                except Exception as e:
                    request.status = DeletionStatus.PENDING.value  # Retry later
                    print(f"Deletion failed for {request.user_id}: {e}")
                
                session.commit()
        finally:
            session.close()
    
    def export_user_data(self, user_id: str) -> UserDataExport:
        """
        Export all user data (Right to Access).
        
        Calls all registered export handlers to collect data.
        """
        session = self.Session()
        try:
            # Create export request record
            export_req = DataExportRequest(
                user_id=user_id,
                status="processing"
            )
            session.add(export_req)
            session.commit()
            
            # Collect data from all services
            service_data = {}
            for service_name, handler in self._export_handlers.items():
                try:
                    service_data[service_name] = handler(user_id)
                except Exception as e:
                    service_data[service_name] = {"error": str(e)}
            
            # Get consents
            from .consent import get_consent_engine
            consent_engine = get_consent_engine()
            consents = consent_engine.get_user_consents(user_id)
            
            # Get audit trail
            from .audit import get_audit_logger
            audit_logger = get_audit_logger("user_rights")
            audit_trail = audit_logger.get_user_audit_trail(user_id, limit=1000)
            
            export_req.status = "completed"
            export_req.completed_at = datetime.utcnow()
            session.commit()
            
            return UserDataExport(
                user_id=user_id,
                export_date=datetime.utcnow(),
                services=service_data,
                consents=[c.model_dump() for c in consents],
                audit_trail=[a.model_dump() for a in audit_trail]
            )
        finally:
            session.close()
    
    def request_correction(self, request: CorrectionRequest) -> Dict[str, Any]:
        """
        Request data correction (Right to Correction).
        
        Routes to appropriate service handler.
        """
        # Determine which service handles this resource type
        service_map = {
            "health_record": "health_records",
            "medication": "medicine",
            "chat": "mental_health",
            "symptom": "diagnostics",
            "sos": "sos"
        }
        
        service = service_map.get(request.resource_type)
        
        if not service or service not in self._correction_handlers:
            return {
                "success": False,
                "error": f"No correction handler for resource type: {request.resource_type}"
            }
        
        try:
            result = self._correction_handlers[service](
                user_id=request.user_id,
                resource_id=request.resource_id,
                field_name=request.field_name,
                corrected_value=request.corrected_value
            )
            return {"success": True, "result": result}
        except Exception as e:
            return {"success": False, "error": str(e)}
    
    def get_deletion_status(self, user_id: str) -> List[Dict[str, Any]]:
        """Get status of all deletion requests for a user"""
        session = self.Session()
        try:
            requests = session.query(DeletionRequest).filter(
                DeletionRequest.user_id == user_id
            ).order_by(DeletionRequest.requested_at.desc()).all()
            
            return [
                {
                    "id": r.id,
                    "status": r.status,
                    "requested_at": r.requested_at.isoformat(),
                    "grace_period_ends": r.grace_period_ends.isoformat() if r.grace_period_ends else None,
                    "completed_at": r.completed_at.isoformat() if r.completed_at else None,
                    "delete_all": r.delete_all,
                    "services": r.services,
                    "data_categories": r.data_categories
                }
                for r in requests
            ]
        finally:
            session.close()


# Singleton
_user_rights_manager: Optional[UserRightsManager] = None

def get_user_rights_manager() -> UserRightsManager:
    global _user_rights_manager
    if _user_rights_manager is None:
        _user_rights_manager = UserRightsManager()
    return _user_rights_manager
