"""
Health Record Database Models
DPDP-compliant with purpose-bound metadata
"""
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, Float, JSON, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from health_record_backend.core.db import Base


class HealthRecord(Base):
    """Main health record document model"""
    __tablename__ = "health_records"
    __table_args__ = {'extend_existing': True}
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), nullable=False, index=True)
    
    # Document metadata
    document_type = Column(String(50), nullable=False)  # prescription, lab_report, radiology, discharge_summary, medical_certificate, other
    document_date = Column(DateTime, nullable=True)
    upload_date = Column(DateTime, default=datetime.utcnow)
    
    # Source information
    doctor_name = Column(String(200), nullable=True)
    hospital_name = Column(String(300), nullable=True)
    patient_name = Column(String(200), nullable=True)
    
    # Diagnosis (only if explicitly stated)
    diagnosis = Column(Text, nullable=True)
    
    # Clinical notes
    notes = Column(Text, nullable=True)
    
    # Original file info (encrypted path)
    file_path = Column(String(500), nullable=True)
    file_hash = Column(String(64), nullable=True)  # SHA-256 for integrity
    
    # OCR extracted raw text (encrypted)
    raw_text = Column(Text, nullable=True)
    
    # Overall confidence score
    confidence_score = Column(Float, default=0.0)
    
    # User verification status
    is_verified = Column(Boolean, default=False)
    verified_at = Column(DateTime, nullable=True)
    
    # DPDP Compliance fields
    purpose_tag = Column(String(100), default="Personal Health Record")
    storage_policy = Column(String(200), default="Encrypted | User-owned | DPDP-compliant")
    consent_given = Column(Boolean, default=False)
    consent_timestamp = Column(DateTime, nullable=True)
    storage_type = Column(String(20), default="permanent")  # permanent, temporary
    auto_delete_date = Column(DateTime, nullable=True)  # For temporary storage
    
    # Emergency access fields
    is_emergency_accessible = Column(Boolean, default=False)
    
    # Soft delete
    is_deleted = Column(Boolean, default=False)
    deleted_at = Column(DateTime, nullable=True)
    
    # Relationships - using lazy="dynamic" to avoid eager loading issues
    medications = relationship("ExtractedMedication", back_populates="health_record", cascade="all, delete-orphan", lazy="dynamic")
    test_results = relationship("ExtractedTestResult", back_populates="health_record", cascade="all, delete-orphan", lazy="dynamic")
    critical_info = relationship("CriticalHealthInfo", back_populates="health_record", cascade="all, delete-orphan", lazy="dynamic")


class ExtractedMedication(Base):
    """Extracted medication information from documents"""
    __tablename__ = "extracted_medications"
    __table_args__ = {'extend_existing': True}
    
    id = Column(Integer, primary_key=True, index=True)
    health_record_id = Column(Integer, ForeignKey("health_records.id"), nullable=False)
    
    name = Column(String(200), nullable=False)
    dosage = Column(String(100), nullable=True)
    frequency = Column(String(100), nullable=True)
    duration = Column(String(100), nullable=True)
    instructions = Column(Text, nullable=True)
    
    confidence = Column(Float, default=0.0)
    is_verified = Column(Boolean, default=False)
    
    health_record = relationship("HealthRecord", back_populates="medications")


class ExtractedTestResult(Base):
    """Extracted test/lab results from documents"""
    __tablename__ = "extracted_test_results"
    __table_args__ = {'extend_existing': True}
    
    id = Column(Integer, primary_key=True, index=True)
    health_record_id = Column(Integer, ForeignKey("health_records.id"), nullable=False)
    
    test_name = Column(String(200), nullable=False)
    result_value = Column(String(100), nullable=True)
    unit = Column(String(50), nullable=True)
    reference_range = Column(String(100), nullable=True)
    is_abnormal = Column(Boolean, default=False)
    
    confidence = Column(Float, default=0.0)
    is_verified = Column(Boolean, default=False)
    
    health_record = relationship("HealthRecord", back_populates="test_results")


class CriticalHealthInfo(Base):
    """Critical health information for emergency access"""
    __tablename__ = "critical_health_info"
    __table_args__ = {'extend_existing': True}
    
    id = Column(Integer, primary_key=True, index=True)
    health_record_id = Column(Integer, ForeignKey("health_records.id"), nullable=True)
    user_id = Column(String(100), nullable=False, index=True)
    
    info_type = Column(String(50), nullable=False)  # blood_group, allergy, chronic_condition
    value = Column(String(500), nullable=False)
    severity = Column(String(20), nullable=True)  # For allergies: mild, moderate, severe
    
    # Emergency sharing consent
    share_in_emergency = Column(Boolean, default=True)
    
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, onupdate=datetime.utcnow)
    
    health_record = relationship("HealthRecord", back_populates="critical_info")


class ConsentLog(Base):
    """Audit log for consent actions - DPDP compliance"""
    __tablename__ = "consent_logs"
    __table_args__ = {'extend_existing': True}
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String(100), nullable=False, index=True)
    health_record_id = Column(Integer, ForeignKey("health_records.id"), nullable=True)
    
    action = Column(String(50), nullable=False)  # consent_given, consent_revoked, data_accessed, data_deleted
    details = Column(Text, nullable=True)
    ip_address = Column(String(50), nullable=True)
    
    timestamp = Column(DateTime, default=datetime.utcnow)
