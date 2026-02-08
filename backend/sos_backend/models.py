from datetime import datetime
from enum import Enum
from typing import Optional, List
from sqlmodel import Field, SQLModel
from pydantic import BaseModel

class SOSStatus(str, Enum):
    TRIGGERED = "Triggered"
    ACKNOWLEDGED = "Acknowledged"
    ON_THE_WAY = "OnTheWay"
    RESOLVED = "Resolved"

class SOSEventBase(SQLModel):
    user_id: str = Field(index=True)
    latitude: float
    longitude: float
    emergency_type: str

class SOSCreate(SOSEventBase):
    pass

class SOSEvent(SOSEventBase, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    timestamp: datetime = Field(default_factory=datetime.utcnow)
    status: SOSStatus = Field(default=SOSStatus.TRIGGERED)
    assigned_ambulance_id: Optional[str] = Field(default=None)
    ambulance_lat: Optional[float] = Field(default=None)
    ambulance_lon: Optional[float] = Field(default=None)
    route_coords: Optional[str] = Field(default=None) # JSON string of [[lon, lat], ...]
    route_progress: int = Field(default=0)
    
    # DPDP Compliance fields
    emergency_consent_id: Optional[int] = Field(default=None)  # Consent granted for this emergency
    consent_expires_at: Optional[datetime] = Field(default=None)  # Auto-revoke time
    data_shared_to: Optional[str] = Field(default=None)  # Hospital/Ambulance ID that received data


class UserEmergencyProfile(SQLModel, table=True):
    """
    User's emergency profile - minimal data shared during SOS.
    DPDP Compliant: User controls what gets shared.
    """
    id: Optional[int] = Field(default=None, primary_key=True)
    user_id: str = Field(unique=True, index=True)
    
    # Essential medical info
    name: Optional[str] = None
    age: Optional[int] = None
    blood_group: Optional[str] = None
    allergies: Optional[str] = None  # JSON array
    chronic_conditions: Optional[str] = None  # JSON array
    current_medications: Optional[str] = None  # JSON array
    
    # Emergency contacts (JSON array)
    emergency_contacts: Optional[str] = None
    
    # Optional fields - user explicitly opts in
    organ_donor: Optional[bool] = None
    insurance_provider: Optional[str] = None
    insurance_id: Optional[str] = None
    
    # Sharing preferences (DPDP: user controls data sharing)
    share_blood_group: bool = True
    share_allergies: bool = True
    share_chronic_conditions: bool = True
    share_current_medications: bool = True
    share_emergency_contacts: bool = True
    share_name: bool = True
    share_age: bool = True
    share_organ_donor_status: bool = False
    share_insurance_info: bool = False
    
    # Settings
    require_manual_confirmation: bool = False
    auto_notify_emergency_contacts: bool = True
    
    updated_at: datetime = Field(default_factory=datetime.utcnow)


class EmergencyProfileUpdate(BaseModel):
    """Request model for updating emergency profile"""
    name: Optional[str] = None
    age: Optional[int] = None
    blood_group: Optional[str] = None
    allergies: Optional[List[str]] = None
    chronic_conditions: Optional[List[str]] = None
    current_medications: Optional[List[str]] = None
    emergency_contacts: Optional[List[dict]] = None
    organ_donor: Optional[bool] = None
    insurance_provider: Optional[str] = None
    insurance_id: Optional[str] = None
    
    # Sharing preferences
    share_blood_group: Optional[bool] = None
    share_allergies: Optional[bool] = None
    share_chronic_conditions: Optional[bool] = None
    share_current_medications: Optional[bool] = None
    share_emergency_contacts: Optional[bool] = None
    share_name: Optional[bool] = None
    share_age: Optional[bool] = None
    share_organ_donor_status: Optional[bool] = None
    share_insurance_info: Optional[bool] = None
    require_manual_confirmation: Optional[bool] = None
    auto_notify_emergency_contacts: Optional[bool] = None


class EmergencyDataResponse(BaseModel):
    """
    Response model for emergency data shared with responders.
    Contains ONLY the minimal data the user has opted to share.
    """
    user_id: str
    name: Optional[str] = None
    age: Optional[int] = None
    blood_group: Optional[str] = None
    allergies: List[str] = []
    chronic_conditions: List[str] = []
    current_medications: List[str] = []
    emergency_contacts: List[dict] = []
    latitude: float
    longitude: float
    emergency_type: str = "Medical"
    status: str = "Unknown"
    organ_donor: Optional[bool] = None
    insurance_provider: Optional[str] = None
    insurance_id: Optional[str] = None
    
    # DPDP metadata
    consent_id: Optional[int] = None
    expires_at: Optional[datetime] = None
    dpdp_notice: str = "This data is shared under emergency consent as per DPDP Act 2023. Access is time-limited and audited."

