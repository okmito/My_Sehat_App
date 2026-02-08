"""
Database Models for Authentication Backend
===========================================

Tables:
- users: Core user information with phone as unique identifier
- user_preferences: User settings and preferences
- user_consents: DPDP compliant consent records
- auth_tokens: Session tokens for persistent login
"""

from datetime import datetime, timedelta
from typing import Optional, List
from enum import Enum
from pydantic import BaseModel, Field
from sqlalchemy import Column, Integer, String, DateTime, Boolean, Text, ForeignKey, create_engine
from sqlalchemy.orm import relationship, declarative_base

Base = declarative_base()


# ==========================================
# SQLAlchemy Models (Database Tables)
# ==========================================

class User(Base):
    """Core user table with phone number as unique identifier"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), nullable=False)
    phone_number = Column(String(15), unique=True, nullable=False, index=True)
    password_hash = Column(String(256), nullable=True)  # Optional for OTP-only auth
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    is_active = Column(Boolean, default=True)
    
    # Additional profile fields
    age = Column(Integer, nullable=True)
    gender = Column(String(20), nullable=True)
    blood_group = Column(String(10), nullable=True)
    allergies = Column(Text, nullable=True)  # JSON string
    conditions = Column(Text, nullable=True)  # JSON string
    emergency_contact = Column(String(100), nullable=True)
    emergency_phone = Column(String(15), nullable=True)
    
    # Relationships
    preferences = relationship("UserPreferences", back_populates="user", uselist=False)
    consents = relationship("UserConsent", back_populates="user")
    tokens = relationship("AuthToken", back_populates="user")


class UserPreferences(Base):
    """User preferences and settings"""
    __tablename__ = "user_preferences"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), unique=True, nullable=False)
    
    # Preferences
    language = Column(String(10), default="en")  # en, hi, etc.
    emergency_enabled = Column(Boolean, default=True)
    medicine_reminders = Column(Boolean, default=True)
    
    # Additional settings
    notification_enabled = Column(Boolean, default=True)
    dark_mode = Column(Boolean, default=False)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    user = relationship("User", back_populates="preferences")


class DataCategory(str, Enum):
    """Categories of personal data under DPDP Act"""
    EMERGENCY = "emergency"
    HEALTH_RECORDS = "health_records"
    AI_SYMPTOMS = "ai_symptoms"
    MENTAL_HEALTH = "mental_health"
    MEDICATIONS = "medications"
    LOCATION = "location"
    DOCUMENTS = "documents"


class ConsentPurpose(str, Enum):
    """Lawful purposes for data processing"""
    EMERGENCY_SHARING = "emergency_sharing"
    HEALTH_RECORD_STORAGE = "health_record_storage"
    AI_SYMPTOM_CHECKER = "ai_symptom_checker"
    MENTAL_HEALTH_PROCESSING = "mental_health_processing"
    MEDICINE_REMINDERS = "medicine_reminders"
    HOSPITAL_SHARING = "hospital_sharing"


class UserConsent(Base):
    """DPDP compliant consent records"""
    __tablename__ = "user_consents"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    data_category = Column(String(50), nullable=False)
    purpose = Column(String(100), nullable=False)
    granted = Column(Boolean, default=False)
    
    # Consent metadata
    consent_text = Column(Text, nullable=True)
    consent_version = Column(String(20), default="1.0")
    
    # Time bounds
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True)
    revoked_at = Column(DateTime, nullable=True)
    
    # Audit
    ip_address = Column(String(50), nullable=True)
    device_info = Column(String(200), nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="consents")


class AuthToken(Base):
    """Session tokens for persistent login"""
    __tablename__ = "auth_tokens"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    
    token = Column(String(500), unique=True, nullable=False, index=True)
    token_type = Column(String(20), default="bearer")
    
    created_at = Column(DateTime, default=datetime.utcnow)
    expires_at = Column(DateTime, nullable=True)  # None = never expires (persistent)
    last_used_at = Column(DateTime, default=datetime.utcnow)
    
    is_active = Column(Boolean, default=True)
    device_info = Column(String(200), nullable=True)
    ip_address = Column(String(50), nullable=True)
    
    # Relationships
    user = relationship("User", back_populates="tokens")


# ==========================================
# Pydantic Models (API Schemas)
# ==========================================

class ConsentItem(BaseModel):
    """Single consent item for signup/update"""
    data_category: str
    purpose: str
    granted: bool
    consent_text: Optional[str] = None


class UserCreate(BaseModel):
    """Schema for user signup"""
    name: str = Field(..., min_length=2, max_length=100)
    phone_number: str = Field(..., pattern=r"^\d{10}$")
    
    # Optional profile fields
    age: Optional[int] = None
    gender: Optional[str] = None
    blood_group: Optional[str] = None
    allergies: Optional[List[str]] = []
    conditions: Optional[List[str]] = []
    emergency_contact: Optional[str] = None
    emergency_phone: Optional[str] = None
    
    # Preferences
    language: str = "en"
    emergency_enabled: bool = True
    medicine_reminders: bool = True
    
    # DPDP Consents (mandatory during signup)
    consents: List[ConsentItem]
    
    class Config:
        json_schema_extra = {
            "example": {
                "name": "Mitesh Sai",
                "phone_number": "9999999999",
                "language": "en",
                "emergency_enabled": True,
                "medicine_reminders": True,
                "consents": [
                    {"data_category": "emergency", "purpose": "emergency_sharing", "granted": True},
                    {"data_category": "health_records", "purpose": "health_record_storage", "granted": True},
                    {"data_category": "ai_symptoms", "purpose": "ai_symptom_checker", "granted": True},
                    {"data_category": "mental_health", "purpose": "mental_health_processing", "granted": False}
                ]
            }
        }


class UserLogin(BaseModel):
    """Schema for user login"""
    phone_number: str = Field(..., pattern=r"^\d{10}$")
    otp: Optional[str] = Field(None, pattern=r"^\d{6}$")  # For OTP based login


class PreferencesCreate(BaseModel):
    """Schema for updating preferences"""
    language: Optional[str] = None
    emergency_enabled: Optional[bool] = None
    medicine_reminders: Optional[bool] = None
    notification_enabled: Optional[bool] = None
    dark_mode: Optional[bool] = None


class ConsentCreate(BaseModel):
    """Schema for creating/updating consent"""
    data_category: str
    purpose: str
    granted: bool
    consent_text: Optional[str] = None
    expires_in_days: Optional[int] = None  # None = never expires


class PreferencesResponse(BaseModel):
    """Response schema for preferences"""
    language: str
    emergency_enabled: bool
    medicine_reminders: bool
    notification_enabled: bool
    dark_mode: bool
    
    class Config:
        from_attributes = True


class ConsentResponse(BaseModel):
    """Response schema for consent"""
    id: int
    data_category: str
    purpose: str
    granted: bool
    consent_text: Optional[str]
    created_at: datetime
    expires_at: Optional[datetime]
    
    class Config:
        from_attributes = True


class UserResponse(BaseModel):
    """Response schema for user data"""
    id: int
    name: str
    phone_number: str
    age: Optional[int]
    gender: Optional[str]
    blood_group: Optional[str]
    allergies: Optional[List[str]]
    conditions: Optional[List[str]]
    emergency_contact: Optional[str]
    emergency_phone: Optional[str]
    created_at: datetime
    preferences: Optional[PreferencesResponse]
    consents: List[ConsentResponse]
    
    class Config:
        from_attributes = True


class TokenResponse(BaseModel):
    """Response schema for auth token"""
    access_token: str
    token_type: str = "bearer"
    user: UserResponse


class SignupResponse(BaseModel):
    """Response schema for signup"""
    message: str
    access_token: str
    token_type: str = "bearer"
    user: UserResponse
