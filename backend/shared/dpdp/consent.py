"""
Central Consent Engine - DPDP Act 2023 Compliance
==================================================

Implements explicit, informed, purpose-specific consent management.
All services MUST check consent before accessing personal data.
"""

from enum import Enum
from datetime import datetime, timedelta
from typing import Optional, List
from pydantic import BaseModel, Field
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Enum as SQLEnum, Text, create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import json
import os

Base = declarative_base()


class DataCategory(str, Enum):
    """Categories of personal data under DPDP Act"""
    LOCATION = "location"
    MENTAL_HEALTH = "mental_health"
    DOCUMENTS = "documents"
    MEDICATIONS = "medications"
    DIAGNOSTICS = "diagnostics"
    EMERGENCY = "emergency"
    HEALTH_RECORDS = "health_records"
    PERSONAL_INFO = "personal_info"


class Purpose(str, Enum):
    """Lawful purposes for data processing under DPDP Act"""
    EMERGENCY = "emergency"           # Life-threatening situations
    TREATMENT = "treatment"           # Medical treatment
    STORAGE = "storage"               # Personal health record storage
    AI_PROCESSING = "ai_processing"   # AI-assisted analysis
    REMINDER = "reminder"             # Medicine reminders
    ANALYTICS = "analytics"           # Personal health analytics
    SHARING = "sharing"               # Sharing with healthcare providers


class ConsentStatus(str, Enum):
    """Status of consent"""
    ACTIVE = "active"
    REVOKED = "revoked"
    EXPIRED = "expired"
    PENDING = "pending"


class GrantedTo(str, Enum):
    """Entities that can receive data access"""
    SELF = "self"
    HOSPITAL = "hospital"
    AMBULANCE = "ambulance"
    AI_SERVICE = "ai_service"
    EMERGENCY_RESPONDER = "emergency_responder"
    HEALTHCARE_WORKER = "healthcare_worker"


# Database Model
class ConsentRecord(Base):
    """SQLAlchemy model for consent records"""
    __tablename__ = "consent_records"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(String(100), nullable=False, index=True)
    data_category = Column(String(50), nullable=False)
    purpose = Column(String(50), nullable=False)
    granted_to = Column(String(50), nullable=False, default="self")
    granted_to_id = Column(String(100), nullable=True)  # Specific entity ID
    
    # Consent metadata
    consent_text = Column(Text, nullable=True)  # What user agreed to
    consent_version = Column(String(20), default="1.0")
    
    # Time bounds
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
    
    # Status
    status = Column(String(20), default=ConsentStatus.ACTIVE.value)
    revocable = Column(Boolean, default=True)
    
    # Audit trail
    ip_address = Column(String(50), nullable=True)
    device_info = Column(String(200), nullable=True)
    consent_method = Column(String(50), default="explicit")  # explicit, implicit, emergency


# Pydantic Schemas
class ConsentCreate(BaseModel):
    """Schema for creating new consent"""
    user_id: str
    data_category: DataCategory
    purpose: Purpose
    granted_to: GrantedTo = GrantedTo.SELF
    granted_to_id: Optional[str] = None
    consent_text: Optional[str] = None
    expires_in_days: Optional[int] = None  # None = no expiry
    ip_address: Optional[str] = None
    device_info: Optional[str] = None


class ConsentResponse(BaseModel):
    """Schema for consent response"""
    id: int
    user_id: str
    data_category: str
    purpose: str
    granted_to: str
    status: str
    created_at: datetime
    expires_at: Optional[datetime]
    revocable: bool
    
    class Config:
        from_attributes = True


class ConsentCheck(BaseModel):
    """Schema for checking consent validity"""
    user_id: str
    data_category: DataCategory
    purpose: Purpose
    granted_to: GrantedTo = GrantedTo.SELF


class ConsentCheckResult(BaseModel):
    """Result of consent check"""
    is_valid: bool
    consent_id: Optional[int] = None
    reason: Optional[str] = None
    expires_at: Optional[datetime] = None


class ConsentEngine:
    """
    Central Consent Engine for DPDP Compliance
    
    All services MUST use this engine to:
    1. Request consent before data collection
    2. Verify consent before data access
    3. Revoke consent when requested
    4. Check consent expiry
    """
    
    def __init__(self, db_url: str = None):
        if db_url is None:
            # Use shared database for consent
            db_path = os.path.join(os.path.dirname(__file__), "..", "..", "consent.db")
            db_url = f"sqlite:///{db_path}"
        
        self.engine = create_engine(db_url, echo=False)
        Base.metadata.create_all(self.engine, checkfirst=True)
        self.Session = sessionmaker(bind=self.engine)
    
    def grant_consent(self, consent: ConsentCreate) -> ConsentResponse:
        """
        Grant explicit consent for data processing.
        Returns consent record for audit trail.
        """
        session = self.Session()
        try:
            # Check if similar consent already exists
            existing = session.query(ConsentRecord).filter(
                ConsentRecord.user_id == consent.user_id,
                ConsentRecord.data_category == consent.data_category.value,
                ConsentRecord.purpose == consent.purpose.value,
                ConsentRecord.granted_to == consent.granted_to.value,
                ConsentRecord.status == ConsentStatus.ACTIVE.value
            ).first()
            
            if existing:
                # Update existing consent
                existing.expires_at = (
                    datetime.utcnow() + timedelta(days=consent.expires_in_days)
                    if consent.expires_in_days else None
                )
                session.commit()
                return ConsentResponse.model_validate(existing)
            
            # Create new consent record
            record = ConsentRecord(
                user_id=consent.user_id,
                data_category=consent.data_category.value,
                purpose=consent.purpose.value,
                granted_to=consent.granted_to.value,
                granted_to_id=consent.granted_to_id,
                consent_text=consent.consent_text,
                expires_at=(
                    datetime.utcnow() + timedelta(days=consent.expires_in_days)
                    if consent.expires_in_days else None
                ),
                ip_address=consent.ip_address,
                device_info=consent.device_info,
                status=ConsentStatus.ACTIVE.value
            )
            
            session.add(record)
            session.commit()
            session.refresh(record)
            
            return ConsentResponse.model_validate(record)
        finally:
            session.close()
    
    def check_consent(self, check: ConsentCheck) -> ConsentCheckResult:
        """
        Verify if valid consent exists for data access.
        
        CRITICAL: This MUST be called before ANY personal data access.
        """
        session = self.Session()
        try:
            record = session.query(ConsentRecord).filter(
                ConsentRecord.user_id == check.user_id,
                ConsentRecord.data_category == check.data_category.value,
                ConsentRecord.purpose == check.purpose.value,
                ConsentRecord.granted_to == check.granted_to.value,
                ConsentRecord.status == ConsentStatus.ACTIVE.value
            ).first()
            
            if not record:
                return ConsentCheckResult(
                    is_valid=False,
                    reason="No active consent found for this data category and purpose"
                )
            
            # Check expiry
            if record.expires_at and record.expires_at < datetime.utcnow():
                record.status = ConsentStatus.EXPIRED.value
                session.commit()
                return ConsentCheckResult(
                    is_valid=False,
                    consent_id=record.id,
                    reason="Consent has expired"
                )
            
            return ConsentCheckResult(
                is_valid=True,
                consent_id=record.id,
                expires_at=record.expires_at
            )
        finally:
            session.close()
    
    def revoke_consent(
        self, 
        user_id: str, 
        data_category: Optional[DataCategory] = None,
        purpose: Optional[Purpose] = None
    ) -> int:
        """
        Revoke consent. Immediately blocks all future data access.
        Returns number of consents revoked.
        """
        session = self.Session()
        try:
            query = session.query(ConsentRecord).filter(
                ConsentRecord.user_id == user_id,
                ConsentRecord.status == ConsentStatus.ACTIVE.value
            )
            
            if data_category:
                query = query.filter(ConsentRecord.data_category == data_category.value)
            if purpose:
                query = query.filter(ConsentRecord.purpose == purpose.value)
            
            records = query.all()
            count = 0
            
            for record in records:
                if record.revocable:
                    record.status = ConsentStatus.REVOKED.value
                    record.revoked_at = datetime.utcnow()
                    count += 1
            
            session.commit()
            return count
        finally:
            session.close()
    
    def get_user_consents(self, user_id: str) -> List[ConsentResponse]:
        """Get all consents for a user (for transparency)"""
        session = self.Session()
        try:
            records = session.query(ConsentRecord).filter(
                ConsentRecord.user_id == user_id
            ).order_by(ConsentRecord.created_at.desc()).all()
            
            return [ConsentResponse.model_validate(r) for r in records]
        finally:
            session.close()
    
    def grant_emergency_consent(
        self, 
        user_id: str,
        emergency_id: str,
        responder_id: str
    ) -> ConsentResponse:
        """
        Emergency override consent - MINIMAL DATA ONLY
        
        DPDP Section 4(2): Processing without consent for emergencies
        Still requires audit trail and auto-revocation.
        """
        session = self.Session()
        try:
            record = ConsentRecord(
                user_id=user_id,
                data_category=DataCategory.EMERGENCY.value,
                purpose=Purpose.EMERGENCY.value,
                granted_to=GrantedTo.EMERGENCY_RESPONDER.value,
                granted_to_id=responder_id,
                consent_text=f"Emergency override for incident {emergency_id}",
                expires_at=datetime.utcnow() + timedelta(hours=24),  # Auto-expire in 24h
                consent_method="emergency",
                revocable=False,  # Cannot revoke during emergency
                status=ConsentStatus.ACTIVE.value
            )
            
            session.add(record)
            session.commit()
            session.refresh(record)
            
            return ConsentResponse.model_validate(record)
        finally:
            session.close()
    
    def revoke_emergency_consent(self, user_id: str, emergency_id: str):
        """Auto-revoke emergency consent when emergency ends"""
        session = self.Session()
        try:
            records = session.query(ConsentRecord).filter(
                ConsentRecord.user_id == user_id,
                ConsentRecord.purpose == Purpose.EMERGENCY.value,
                ConsentRecord.consent_text.like(f"%{emergency_id}%"),
                ConsentRecord.status == ConsentStatus.ACTIVE.value
            ).all()
            
            for record in records:
                record.status = ConsentStatus.REVOKED.value
                record.revoked_at = datetime.utcnow()
            
            session.commit()
            return len(records)
        finally:
            session.close()


# Decorator for consent-protected endpoints
def require_consent(data_category: DataCategory, purpose: Purpose, granted_to: GrantedTo = GrantedTo.SELF):
    """
    Decorator to enforce consent check on endpoints.
    
    Usage:
        @require_consent(DataCategory.HEALTH_RECORDS, Purpose.STORAGE)
        async def get_records(user_id: str):
            ...
    """
    def decorator(func):
        async def wrapper(*args, **kwargs):
            user_id = kwargs.get('user_id') or kwargs.get('current_user_id')
            if not user_id:
                raise ValueError("user_id required for consent check")
            
            engine = ConsentEngine()
            result = engine.check_consent(ConsentCheck(
                user_id=user_id,
                data_category=data_category,
                purpose=purpose,
                granted_to=granted_to
            ))
            
            if not result.is_valid:
                from fastapi import HTTPException
                raise HTTPException(
                    status_code=403,
                    detail=f"Consent required: {result.reason}"
                )
            
            # Inject consent_id for audit trail
            kwargs['_consent_id'] = result.consent_id
            return await func(*args, **kwargs)
        
        wrapper.__name__ = func.__name__
        return wrapper
    return decorator


# Singleton instance
_consent_engine: Optional[ConsentEngine] = None

def get_consent_engine() -> ConsentEngine:
    """Get singleton consent engine instance"""
    global _consent_engine
    if _consent_engine is None:
        _consent_engine = ConsentEngine()
    return _consent_engine
