"""
Pydantic schemas for Health Record API
"""
from pydantic import BaseModel, Field
from typing import Optional, List
from datetime import datetime
from enum import Enum


class DocumentType(str, Enum):
    PRESCRIPTION = "prescription"
    LAB_REPORT = "lab_report"
    RADIOLOGY = "radiology"
    DISCHARGE_SUMMARY = "discharge_summary"
    MEDICAL_CERTIFICATE = "medical_certificate"
    OTHER = "other"


class StorageType(str, Enum):
    PERMANENT = "permanent"
    TEMPORARY = "temporary"
    DO_NOT_STORE = "do_not_store"


class CriticalInfoType(str, Enum):
    BLOOD_GROUP = "blood_group"
    ALLERGY = "allergy"
    CHRONIC_CONDITION = "chronic_condition"


# Medication schemas
class MedicationBase(BaseModel):
    name: str
    dosage: Optional[str] = None
    frequency: Optional[str] = None
    duration: Optional[str] = None
    instructions: Optional[str] = None
    confidence: float = 0.0


class MedicationResponse(MedicationBase):
    id: int
    is_verified: bool = False
    
    class Config:
        from_attributes = True


# Test result schemas
class TestResultBase(BaseModel):
    test_name: str
    result_value: Optional[str] = None
    unit: Optional[str] = None
    reference_range: Optional[str] = None
    is_abnormal: bool = False
    confidence: float = 0.0


class TestResultResponse(TestResultBase):
    id: int
    is_verified: bool = False
    
    class Config:
        from_attributes = True


# Critical info schemas
class CriticalInfoBase(BaseModel):
    info_type: CriticalInfoType
    value: str
    severity: Optional[str] = None
    share_in_emergency: bool = True


class CriticalInfoResponse(CriticalInfoBase):
    id: int
    user_id: str
    created_at: datetime
    
    class Config:
        from_attributes = True


# Health record schemas
class HealthRecordBase(BaseModel):
    document_type: DocumentType
    document_date: Optional[datetime] = None
    doctor_name: Optional[str] = None
    hospital_name: Optional[str] = None
    patient_name: Optional[str] = None
    diagnosis: Optional[str] = None
    notes: Optional[str] = None


class HealthRecordCreate(HealthRecordBase):
    user_id: str
    storage_type: StorageType = StorageType.PERMANENT
    consent_given: bool = False


class HealthRecordResponse(HealthRecordBase):
    id: int
    user_id: str
    upload_date: datetime
    confidence_score: float
    is_verified: bool
    purpose_tag: str
    storage_policy: str
    medications: List[MedicationResponse] = []
    test_results: List[TestResultResponse] = []
    
    class Config:
        from_attributes = True


class HealthRecordListResponse(BaseModel):
    id: int
    user_id: str
    document_type: DocumentType
    document_date: Optional[datetime]
    upload_date: datetime
    doctor_name: Optional[str]
    hospital_name: Optional[str]
    confidence_score: float
    is_verified: bool
    is_emergency_accessible: bool
    
    class Config:
        from_attributes = True


# Document analysis schemas
class DocumentAnalysisRequest(BaseModel):
    user_id: str
    storage_type: StorageType = StorageType.PERMANENT
    consent_given: bool = False


class DocumentAnalysisResponse(BaseModel):
    document_type: str
    date: Optional[str] = None
    doctor: Optional[str] = None
    hospital: Optional[str] = None
    patient_name: Optional[str] = None
    diagnosis: Optional[str] = None
    medications: List[MedicationBase] = []
    test_results: List[TestResultBase] = []
    notes: Optional[str] = None
    critical_info: List[CriticalInfoBase] = []
    overall_confidence: float = 0.0
    purpose_tag: str = "Personal Health Record"
    storage_policy: str = "Encrypted | User-owned | DPDP-compliant"
    ai_disclaimer: str = "This information is extracted from uploaded documents. It is not a medical diagnosis and should be verified by a professional."


# Consent schemas
class ConsentRequest(BaseModel):
    user_id: str
    consent_given: bool
    storage_type: StorageType


class ConsentResponse(BaseModel):
    success: bool
    message: str
    storage_type: StorageType
    auto_delete_date: Optional[datetime] = None


# Emergency data schemas
class EmergencyDataResponse(BaseModel):
    blood_group: Optional[str] = None
    allergies: List[dict] = []
    chronic_conditions: List[str] = []
    disclaimer: str = "Emergency responders see only life-critical information, nothing else."


# Timeline schemas
class TimelineEntry(BaseModel):
    id: int
    date: datetime
    document_type: DocumentType
    title: str
    doctor_name: Optional[str] = None
    hospital_name: Optional[str] = None
    
    class Config:
        from_attributes = True


class TimelineResponse(BaseModel):
    entries: List[TimelineEntry]
    total_count: int


# Search schemas
class SearchRequest(BaseModel):
    user_id: str
    query: Optional[str] = None
    document_type: Optional[DocumentType] = None
    doctor_name: Optional[str] = None
    hospital_name: Optional[str] = None
    date_from: Optional[datetime] = None
    date_to: Optional[datetime] = None
    medicine_name: Optional[str] = None


class VerificationRequest(BaseModel):
    user_id: str
    record_id: int
    verified_data: HealthRecordBase
    medications: List[MedicationBase] = []
    test_results: List[TestResultBase] = []
