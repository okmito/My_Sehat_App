"""
FHIR R4 Base Models
====================

Base classes and common types for HL7 FHIR R4 resources.
All FHIR resources follow the official HL7 FHIR R4 specification.

Reference: https://hl7.org/fhir/R4/
"""

from typing import Optional, List, Dict, Any, Literal
from datetime import datetime, date
from pydantic import BaseModel, Field
from enum import Enum


class FHIRResourceType(str, Enum):
    """FHIR R4 Resource Types"""
    PATIENT = "Patient"
    OBSERVATION = "Observation"
    CONDITION = "Condition"
    MEDICATION = "Medication"
    MEDICATION_REQUEST = "MedicationRequest"
    DIAGNOSTIC_REPORT = "DiagnosticReport"
    DOCUMENT_REFERENCE = "DocumentReference"
    ENCOUNTER = "Encounter"
    ALLERGY_INTOLERANCE = "AllergyIntolerance"
    BUNDLE = "Bundle"


class NarrativeStatus(str, Enum):
    """Status of the narrative text"""
    GENERATED = "generated"
    EXTENSIONS = "extensions"
    ADDITIONAL = "additional"
    EMPTY = "empty"


class BundleType(str, Enum):
    """Type of FHIR Bundle"""
    DOCUMENT = "document"
    MESSAGE = "message"
    TRANSACTION = "transaction"
    TRANSACTION_RESPONSE = "transaction-response"
    BATCH = "batch"
    BATCH_RESPONSE = "batch-response"
    HISTORY = "history"
    SEARCHSET = "searchset"
    COLLECTION = "collection"


# --- FHIR Base Elements ---

class Coding(BaseModel):
    """FHIR Coding element"""
    system: Optional[str] = None
    version: Optional[str] = None
    code: Optional[str] = None
    display: Optional[str] = None
    userSelected: Optional[bool] = None


class CodeableConcept(BaseModel):
    """FHIR CodeableConcept element"""
    coding: List[Coding] = []
    text: Optional[str] = None


class Identifier(BaseModel):
    """FHIR Identifier element"""
    use: Optional[str] = None  # usual | official | temp | secondary | old
    type: Optional[CodeableConcept] = None
    system: Optional[str] = None
    value: Optional[str] = None
    period: Optional[Dict[str, str]] = None


class HumanName(BaseModel):
    """FHIR HumanName element"""
    use: Optional[str] = None  # usual | official | temp | nickname | anonymous | old | maiden
    text: Optional[str] = None
    family: Optional[str] = None
    given: List[str] = []
    prefix: List[str] = []
    suffix: List[str] = []
    period: Optional[Dict[str, str]] = None


class ContactPoint(BaseModel):
    """FHIR ContactPoint element"""
    system: Optional[str] = None  # phone | fax | email | pager | url | sms | other
    value: Optional[str] = None
    use: Optional[str] = None  # home | work | temp | old | mobile
    rank: Optional[int] = None


class Address(BaseModel):
    """FHIR Address element"""
    use: Optional[str] = None  # home | work | temp | old | billing
    type: Optional[str] = None  # postal | physical | both
    text: Optional[str] = None
    line: List[str] = []
    city: Optional[str] = None
    district: Optional[str] = None
    state: Optional[str] = None
    postalCode: Optional[str] = None
    country: Optional[str] = None


class Reference(BaseModel):
    """FHIR Reference element"""
    reference: Optional[str] = None
    type: Optional[str] = None
    identifier: Optional[Identifier] = None
    display: Optional[str] = None


class Period(BaseModel):
    """FHIR Period element"""
    start: Optional[str] = None
    end: Optional[str] = None


class Quantity(BaseModel):
    """FHIR Quantity element"""
    value: Optional[float] = None
    comparator: Optional[str] = None
    unit: Optional[str] = None
    system: Optional[str] = None
    code: Optional[str] = None


class Range(BaseModel):
    """FHIR Range element"""
    low: Optional[Quantity] = None
    high: Optional[Quantity] = None


class Narrative(BaseModel):
    """FHIR Narrative element"""
    status: NarrativeStatus = NarrativeStatus.GENERATED
    div: str = "<div xmlns=\"http://www.w3.org/1999/xhtml\"></div>"


class Meta(BaseModel):
    """FHIR Meta element"""
    versionId: Optional[str] = None
    lastUpdated: Optional[str] = None
    source: Optional[str] = None
    profile: List[str] = []
    security: List[Coding] = []
    tag: List[Coding] = []


class Attachment(BaseModel):
    """FHIR Attachment element"""
    contentType: Optional[str] = None
    language: Optional[str] = None
    data: Optional[str] = None  # Base64
    url: Optional[str] = None
    size: Optional[int] = None
    hash: Optional[str] = None
    title: Optional[str] = None
    creation: Optional[str] = None


class Annotation(BaseModel):
    """FHIR Annotation element"""
    authorReference: Optional[Reference] = None
    authorString: Optional[str] = None
    time: Optional[str] = None
    text: str


# --- FHIR Base Resource ---

class FHIRResource(BaseModel):
    """Base class for all FHIR Resources"""
    resourceType: str
    id: Optional[str] = None
    meta: Optional[Meta] = None
    implicitRules: Optional[str] = None
    language: Optional[str] = None
    
    class Config:
        populate_by_name = True
        json_schema_extra = {
            "example": {
                "resourceType": "Resource",
                "id": "example-id"
            }
        }


class DomainResource(FHIRResource):
    """Base class for FHIR Domain Resources"""
    text: Optional[Narrative] = None
    contained: List[Any] = []
    extension: List[Any] = []
    modifierExtension: List[Any] = []
