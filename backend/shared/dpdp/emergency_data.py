"""
Emergency Data Access Module - DPDP Act 2023 Compliance
========================================================

Defines what personal data is accessible during emergencies.
Implements MINIMAL DATA principle for emergency situations.
"""

from enum import Enum
from typing import Optional, Dict, Any, List
from pydantic import BaseModel
from datetime import datetime


class EmergencyDataField(str, Enum):
    """Fields that CAN be shared during emergency - WHITELIST approach"""
    # Essential for immediate care
    BLOOD_GROUP = "blood_group"
    ALLERGIES = "allergies"
    CHRONIC_CONDITIONS = "chronic_conditions"
    CURRENT_MEDICATIONS = "current_medications"
    
    # Essential for contact
    EMERGENCY_CONTACTS = "emergency_contacts"
    
    # Essential for location
    CURRENT_LOCATION = "current_location"
    
    # Essential for identification
    NAME = "name"
    AGE = "age"
    
    # Optional - user can include/exclude
    ORGAN_DONOR_STATUS = "organ_donor_status"
    INSURANCE_INFO = "insurance_info"


class RestrictedDataField(str, Enum):
    """Fields BLOCKED from emergency access - BLACKLIST"""
    MENTAL_HEALTH_NOTES = "mental_health_notes"
    MENTAL_HEALTH_SESSIONS = "mental_health_sessions"
    FULL_MEDICAL_HISTORY = "full_medical_history"
    DIAGNOSTIC_HISTORY = "diagnostic_history"
    PERSONAL_DOCUMENTS = "personal_documents"
    FINANCIAL_RECORDS = "financial_records"
    MEDICATION_ADHERENCE = "medication_adherence"
    AI_CONVERSATIONS = "ai_conversations"


class EmergencyDataPacket(BaseModel):
    """
    Minimal data packet shared during emergency.
    Contains ONLY essential information for immediate care.
    """
    # User identification (minimal)
    user_id: str
    name: Optional[str] = None
    age: Optional[int] = None
    
    # Critical medical info
    blood_group: Optional[str] = None
    allergies: List[str] = []
    chronic_conditions: List[str] = []
    current_medications: List[str] = []
    
    # Emergency contacts
    emergency_contacts: List[Dict[str, str]] = []
    
    # Location
    latitude: float
    longitude: float
    address: Optional[str] = None
    
    # Optional
    organ_donor: Optional[bool] = None
    insurance_provider: Optional[str] = None
    insurance_id: Optional[str] = None
    
    # Metadata
    packet_created_at: datetime
    consent_id: Optional[int] = None
    expires_at: Optional[datetime] = None
    
    class Config:
        json_schema_extra = {
            "example": {
                "user_id": "user123",
                "name": "John Doe",
                "age": 35,
                "blood_group": "O+",
                "allergies": ["Penicillin", "Peanuts"],
                "chronic_conditions": ["Type 2 Diabetes", "Hypertension"],
                "current_medications": ["Metformin 500mg", "Amlodipine 5mg"],
                "emergency_contacts": [
                    {"name": "Jane Doe", "phone": "+91-9876543210", "relation": "Spouse"}
                ],
                "latitude": 12.9716,
                "longitude": 77.5946,
                "organ_donor": True
            }
        }


class EmergencyAccessConfig(BaseModel):
    """User configuration for emergency data access"""
    user_id: str
    
    # Fields user has opted to share
    share_blood_group: bool = True
    share_allergies: bool = True
    share_chronic_conditions: bool = True
    share_current_medications: bool = True
    share_emergency_contacts: bool = True
    share_name: bool = True
    share_age: bool = True
    share_organ_donor_status: bool = False
    share_insurance_info: bool = False
    
    # Override settings
    require_manual_confirmation: bool = False  # If True, SOS won't share until user confirms
    auto_notify_emergency_contacts: bool = True


def get_emergency_data_packet(
    user_id: str,
    config: EmergencyAccessConfig,
    user_profile: Dict[str, Any],
    location: tuple[float, float],
    consent_id: Optional[int] = None,
    expires_at: Optional[datetime] = None
) -> EmergencyDataPacket:
    """
    Build minimal emergency data packet based on user config.
    
    ONLY includes fields user has opted to share.
    """
    packet = EmergencyDataPacket(
        user_id=user_id,
        latitude=location[0],
        longitude=location[1],
        packet_created_at=datetime.utcnow(),
        consent_id=consent_id,
        expires_at=expires_at
    )
    
    # Only include opted-in fields
    if config.share_name and "name" in user_profile:
        packet.name = user_profile["name"]
    
    if config.share_age and "age" in user_profile:
        packet.age = user_profile["age"]
    
    if config.share_blood_group and "blood_group" in user_profile:
        packet.blood_group = user_profile["blood_group"]
    
    if config.share_allergies and "allergies" in user_profile:
        packet.allergies = user_profile.get("allergies", [])
    
    if config.share_chronic_conditions and "chronic_conditions" in user_profile:
        packet.chronic_conditions = user_profile.get("chronic_conditions", [])
    
    if config.share_current_medications and "current_medications" in user_profile:
        packet.current_medications = user_profile.get("current_medications", [])
    
    if config.share_emergency_contacts and "emergency_contacts" in user_profile:
        packet.emergency_contacts = user_profile.get("emergency_contacts", [])
    
    if config.share_organ_donor_status and "organ_donor" in user_profile:
        packet.organ_donor = user_profile.get("organ_donor")
    
    if config.share_insurance_info:
        packet.insurance_provider = user_profile.get("insurance_provider")
        packet.insurance_id = user_profile.get("insurance_id")
    
    return packet


# Default emergency config (user can modify in settings)
DEFAULT_EMERGENCY_CONFIG = {
    "share_blood_group": True,
    "share_allergies": True,
    "share_chronic_conditions": True,
    "share_current_medications": True,
    "share_emergency_contacts": True,
    "share_name": True,
    "share_age": True,
    "share_organ_donor_status": False,
    "share_insurance_info": False,
    "require_manual_confirmation": False,
    "auto_notify_emergency_contacts": True
}
