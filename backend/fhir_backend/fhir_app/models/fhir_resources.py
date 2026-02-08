"""
FHIR R4 Resource Models
========================

Complete HL7 FHIR R4 resource definitions for:
- Patient
- Observation
- Condition
- Medication
- MedicationRequest
- DiagnosticReport
- DocumentReference
- Encounter
- AllergyIntolerance
- Bundle

All models follow official FHIR R4 structure.
"""

from typing import Optional, List, Dict, Any, Union, Literal
from datetime import datetime, date
from pydantic import BaseModel, Field
from enum import Enum

from .fhir_base import (
    FHIRResource, DomainResource, FHIRResourceType,
    Identifier, HumanName, ContactPoint, Address, Reference,
    CodeableConcept, Coding, Period, Quantity, Range,
    Narrative, Meta, Attachment, Annotation, BundleType, NarrativeStatus
)


# --- Patient Resource ---

class PatientContact(BaseModel):
    """A contact party for the patient"""
    relationship: List[CodeableConcept] = []
    name: Optional[HumanName] = None
    telecom: List[ContactPoint] = []
    address: Optional[Address] = None
    gender: Optional[str] = None
    organization: Optional[Reference] = None
    period: Optional[Period] = None


class PatientCommunication(BaseModel):
    """Language communication capability"""
    language: CodeableConcept
    preferred: Optional[bool] = None


class PatientLink(BaseModel):
    """Link to another patient resource"""
    other: Reference
    type: str  # replaced-by | replaces | refer | seealso


class FHIRPatient(DomainResource):
    """
    FHIR R4 Patient Resource
    
    Demographics and other administrative information about an individual
    receiving care or other health-related services.
    """
    resourceType: Literal["Patient"] = "Patient"
    
    identifier: List[Identifier] = []
    active: Optional[bool] = True
    name: List[HumanName] = []
    telecom: List[ContactPoint] = []
    gender: Optional[str] = None  # male | female | other | unknown
    birthDate: Optional[str] = None  # YYYY-MM-DD
    deceasedBoolean: Optional[bool] = None
    deceasedDateTime: Optional[str] = None
    address: List[Address] = []
    maritalStatus: Optional[CodeableConcept] = None
    multipleBirthBoolean: Optional[bool] = None
    multipleBirthInteger: Optional[int] = None
    photo: List[Attachment] = []
    contact: List[PatientContact] = []
    communication: List[PatientCommunication] = []
    generalPractitioner: List[Reference] = []
    managingOrganization: Optional[Reference] = None
    link: List[PatientLink] = []
    
    # Extension for blood group (commonly needed in healthcare)
    extension: List[Dict[str, Any]] = []


# --- Observation Resource ---

class ObservationReferenceRange(BaseModel):
    """Reference range for observation"""
    low: Optional[Quantity] = None
    high: Optional[Quantity] = None
    type: Optional[CodeableConcept] = None
    appliesTo: List[CodeableConcept] = []
    age: Optional[Range] = None
    text: Optional[str] = None


class ObservationComponent(BaseModel):
    """Component results"""
    code: CodeableConcept
    valueQuantity: Optional[Quantity] = None
    valueCodeableConcept: Optional[CodeableConcept] = None
    valueString: Optional[str] = None
    valueBoolean: Optional[bool] = None
    valueInteger: Optional[int] = None
    valueRange: Optional[Range] = None
    valueRatio: Optional[Dict[str, Quantity]] = None
    valueSampledData: Optional[Dict[str, Any]] = None
    valueTime: Optional[str] = None
    valueDateTime: Optional[str] = None
    valuePeriod: Optional[Period] = None
    dataAbsentReason: Optional[CodeableConcept] = None
    interpretation: List[CodeableConcept] = []
    referenceRange: List[ObservationReferenceRange] = []


class FHIRObservation(DomainResource):
    """
    FHIR R4 Observation Resource
    
    Measurements and simple assertions made about a patient.
    Used for symptom checks, vitals, lab results interpretations, etc.
    """
    resourceType: Literal["Observation"] = "Observation"
    
    identifier: List[Identifier] = []
    basedOn: List[Reference] = []
    partOf: List[Reference] = []
    status: str  # registered | preliminary | final | amended | corrected | cancelled | entered-in-error | unknown
    category: List[CodeableConcept] = []
    code: CodeableConcept
    subject: Optional[Reference] = None
    focus: List[Reference] = []
    encounter: Optional[Reference] = None
    effectiveDateTime: Optional[str] = None
    effectivePeriod: Optional[Period] = None
    effectiveTiming: Optional[Dict[str, Any]] = None
    effectiveInstant: Optional[str] = None
    issued: Optional[str] = None
    performer: List[Reference] = []
    valueQuantity: Optional[Quantity] = None
    valueCodeableConcept: Optional[CodeableConcept] = None
    valueString: Optional[str] = None
    valueBoolean: Optional[bool] = None
    valueInteger: Optional[int] = None
    valueRange: Optional[Range] = None
    valueRatio: Optional[Dict[str, Quantity]] = None
    valueSampledData: Optional[Dict[str, Any]] = None
    valueTime: Optional[str] = None
    valueDateTime: Optional[str] = None
    valuePeriod: Optional[Period] = None
    dataAbsentReason: Optional[CodeableConcept] = None
    interpretation: List[CodeableConcept] = []
    note: List[Annotation] = []
    bodySite: Optional[CodeableConcept] = None
    method: Optional[CodeableConcept] = None
    specimen: Optional[Reference] = None
    device: Optional[Reference] = None
    referenceRange: List[ObservationReferenceRange] = []
    hasMember: List[Reference] = []
    derivedFrom: List[Reference] = []
    component: List[ObservationComponent] = []


# --- Condition Resource ---

class ConditionStage(BaseModel):
    """Stage/grade of condition"""
    summary: Optional[CodeableConcept] = None
    assessment: List[Reference] = []
    type: Optional[CodeableConcept] = None


class ConditionEvidence(BaseModel):
    """Supporting evidence"""
    code: List[CodeableConcept] = []
    detail: List[Reference] = []


class FHIRCondition(DomainResource):
    """
    FHIR R4 Condition Resource
    
    A clinical condition, problem, diagnosis, or other event, situation,
    issue, or clinical concept that has risen to a level of concern.
    """
    resourceType: Literal["Condition"] = "Condition"
    
    identifier: List[Identifier] = []
    clinicalStatus: Optional[CodeableConcept] = None
    verificationStatus: Optional[CodeableConcept] = None
    category: List[CodeableConcept] = []
    severity: Optional[CodeableConcept] = None
    code: Optional[CodeableConcept] = None
    bodySite: List[CodeableConcept] = []
    subject: Reference
    encounter: Optional[Reference] = None
    onsetDateTime: Optional[str] = None
    onsetAge: Optional[Dict[str, Any]] = None
    onsetPeriod: Optional[Period] = None
    onsetRange: Optional[Range] = None
    onsetString: Optional[str] = None
    abatementDateTime: Optional[str] = None
    abatementAge: Optional[Dict[str, Any]] = None
    abatementPeriod: Optional[Period] = None
    abatementRange: Optional[Range] = None
    abatementString: Optional[str] = None
    recordedDate: Optional[str] = None
    recorder: Optional[Reference] = None
    asserter: Optional[Reference] = None
    stage: List[ConditionStage] = []
    evidence: List[ConditionEvidence] = []
    note: List[Annotation] = []


# --- Medication Resource ---

class MedicationIngredient(BaseModel):
    """Active or inactive ingredient"""
    itemCodeableConcept: Optional[CodeableConcept] = None
    itemReference: Optional[Reference] = None
    isActive: Optional[bool] = None
    strength: Optional[Dict[str, Quantity]] = None


class MedicationBatch(BaseModel):
    """Batch info for medication"""
    lotNumber: Optional[str] = None
    expirationDate: Optional[str] = None


class FHIRMedication(DomainResource):
    """
    FHIR R4 Medication Resource
    
    A medication item - identifies the medication and its packaging.
    """
    resourceType: Literal["Medication"] = "Medication"
    
    identifier: List[Identifier] = []
    code: Optional[CodeableConcept] = None
    status: Optional[str] = None  # active | inactive | entered-in-error
    manufacturer: Optional[Reference] = None
    form: Optional[CodeableConcept] = None
    amount: Optional[Dict[str, Quantity]] = None
    ingredient: List[MedicationIngredient] = []
    batch: Optional[MedicationBatch] = None


# --- MedicationRequest Resource ---

class MedicationRequestDispenseRequest(BaseModel):
    """Medication supply authorization"""
    initialFill: Optional[Dict[str, Any]] = None
    dispenseInterval: Optional[Dict[str, Any]] = None
    validityPeriod: Optional[Period] = None
    numberOfRepeatsAllowed: Optional[int] = None
    quantity: Optional[Quantity] = None
    expectedSupplyDuration: Optional[Dict[str, Any]] = None
    performer: Optional[Reference] = None


class MedicationRequestSubstitution(BaseModel):
    """Any restrictions on medication substitution"""
    allowedBoolean: Optional[bool] = None
    allowedCodeableConcept: Optional[CodeableConcept] = None
    reason: Optional[CodeableConcept] = None


class Dosage(BaseModel):
    """How the medication is/was taken or should be taken"""
    sequence: Optional[int] = None
    text: Optional[str] = None
    additionalInstruction: List[CodeableConcept] = []
    patientInstruction: Optional[str] = None
    timing: Optional[Dict[str, Any]] = None
    asNeededBoolean: Optional[bool] = None
    asNeededCodeableConcept: Optional[CodeableConcept] = None
    site: Optional[CodeableConcept] = None
    route: Optional[CodeableConcept] = None
    method: Optional[CodeableConcept] = None
    doseAndRate: List[Dict[str, Any]] = []
    maxDosePerPeriod: Optional[Dict[str, Quantity]] = None
    maxDosePerAdministration: Optional[Quantity] = None
    maxDosePerLifetime: Optional[Quantity] = None


class FHIRMedicationRequest(DomainResource):
    """
    FHIR R4 MedicationRequest Resource
    
    An order or request for both supply of the medication and the 
    instructions for administration of the medication to a patient.
    """
    resourceType: Literal["MedicationRequest"] = "MedicationRequest"
    
    identifier: List[Identifier] = []
    status: str  # active | on-hold | cancelled | completed | entered-in-error | stopped | draft | unknown
    statusReason: Optional[CodeableConcept] = None
    intent: str  # proposal | plan | order | original-order | reflex-order | filler-order | instance-order | option
    category: List[CodeableConcept] = []
    priority: Optional[str] = None  # routine | urgent | asap | stat
    doNotPerform: Optional[bool] = None
    reportedBoolean: Optional[bool] = None
    reportedReference: Optional[Reference] = None
    medicationCodeableConcept: Optional[CodeableConcept] = None
    medicationReference: Optional[Reference] = None
    subject: Reference
    encounter: Optional[Reference] = None
    supportingInformation: List[Reference] = []
    authoredOn: Optional[str] = None
    requester: Optional[Reference] = None
    performer: Optional[Reference] = None
    performerType: Optional[CodeableConcept] = None
    recorder: Optional[Reference] = None
    reasonCode: List[CodeableConcept] = []
    reasonReference: List[Reference] = []
    instantiatesCanonical: List[str] = []
    instantiatesUri: List[str] = []
    basedOn: List[Reference] = []
    groupIdentifier: Optional[Identifier] = None
    courseOfTherapyType: Optional[CodeableConcept] = None
    insurance: List[Reference] = []
    note: List[Annotation] = []
    dosageInstruction: List[Dosage] = []
    dispenseRequest: Optional[MedicationRequestDispenseRequest] = None
    substitution: Optional[MedicationRequestSubstitution] = None
    priorPrescription: Optional[Reference] = None
    detectedIssue: List[Reference] = []
    eventHistory: List[Reference] = []


# --- DiagnosticReport Resource ---

class DiagnosticReportMedia(BaseModel):
    """Key images associated with the report"""
    comment: Optional[str] = None
    link: Reference


class FHIRDiagnosticReport(DomainResource):
    """
    FHIR R4 DiagnosticReport Resource
    
    The findings and interpretation of diagnostic tests performed on patients.
    """
    resourceType: Literal["DiagnosticReport"] = "DiagnosticReport"
    
    identifier: List[Identifier] = []
    basedOn: List[Reference] = []
    status: str  # registered | partial | preliminary | final | amended | corrected | appended | cancelled | entered-in-error | unknown
    category: List[CodeableConcept] = []
    code: CodeableConcept
    subject: Optional[Reference] = None
    encounter: Optional[Reference] = None
    effectiveDateTime: Optional[str] = None
    effectivePeriod: Optional[Period] = None
    issued: Optional[str] = None
    performer: List[Reference] = []
    resultsInterpreter: List[Reference] = []
    specimen: List[Reference] = []
    result: List[Reference] = []
    imagingStudy: List[Reference] = []
    media: List[DiagnosticReportMedia] = []
    conclusion: Optional[str] = None
    conclusionCode: List[CodeableConcept] = []
    presentedForm: List[Attachment] = []


# --- DocumentReference Resource ---

class DocumentReferenceRelatesTo(BaseModel):
    """Relationships to other documents"""
    code: str  # replaces | transforms | signs | appends
    target: Reference


class DocumentReferenceContent(BaseModel):
    """Document content"""
    attachment: Attachment
    format: Optional[Coding] = None


class DocumentReferenceContext(BaseModel):
    """Clinical context of document"""
    encounter: List[Reference] = []
    event: List[CodeableConcept] = []
    period: Optional[Period] = None
    facilityType: Optional[CodeableConcept] = None
    practiceSetting: Optional[CodeableConcept] = None
    sourcePatientInfo: Optional[Reference] = None
    related: List[Reference] = []


class FHIRDocumentReference(DomainResource):
    """
    FHIR R4 DocumentReference Resource
    
    A reference to a document of any kind for any purpose.
    """
    resourceType: Literal["DocumentReference"] = "DocumentReference"
    
    masterIdentifier: Optional[Identifier] = None
    identifier: List[Identifier] = []
    status: str  # current | superseded | entered-in-error
    docStatus: Optional[str] = None  # preliminary | final | amended | entered-in-error
    type: Optional[CodeableConcept] = None
    category: List[CodeableConcept] = []
    subject: Optional[Reference] = None
    date: Optional[str] = None
    author: List[Reference] = []
    authenticator: Optional[Reference] = None
    custodian: Optional[Reference] = None
    relatesTo: List[DocumentReferenceRelatesTo] = []
    description: Optional[str] = None
    securityLabel: List[CodeableConcept] = []
    content: List[DocumentReferenceContent] = []
    context: Optional[DocumentReferenceContext] = None


# --- Encounter Resource ---

class EncounterStatusHistory(BaseModel):
    """List of past encounter statuses"""
    status: str
    period: Period


class EncounterClassHistory(BaseModel):
    """List of past encounter classes"""
    class_: Coding = Field(alias="class")
    period: Period
    
    class Config:
        populate_by_name = True


class EncounterParticipant(BaseModel):
    """List of participants involved in encounter"""
    type: List[CodeableConcept] = []
    period: Optional[Period] = None
    individual: Optional[Reference] = None


class EncounterDiagnosis(BaseModel):
    """Diagnoses relevant to encounter"""
    condition: Reference
    use: Optional[CodeableConcept] = None
    rank: Optional[int] = None


class EncounterHospitalization(BaseModel):
    """Details about hospitalization"""
    preAdmissionIdentifier: Optional[Identifier] = None
    origin: Optional[Reference] = None
    admitSource: Optional[CodeableConcept] = None
    reAdmission: Optional[CodeableConcept] = None
    dietPreference: List[CodeableConcept] = []
    specialCourtesy: List[CodeableConcept] = []
    specialArrangement: List[CodeableConcept] = []
    destination: Optional[Reference] = None
    dischargeDisposition: Optional[CodeableConcept] = None


class EncounterLocation(BaseModel):
    """Location during encounter"""
    location: Reference
    status: Optional[str] = None  # planned | active | reserved | completed
    physicalType: Optional[CodeableConcept] = None
    period: Optional[Period] = None


class FHIREncounter(DomainResource):
    """
    FHIR R4 Encounter Resource
    
    An interaction between a patient and healthcare provider(s).
    """
    resourceType: Literal["Encounter"] = "Encounter"
    
    identifier: List[Identifier] = []
    status: str  # planned | arrived | triaged | in-progress | onleave | finished | cancelled | entered-in-error | unknown
    statusHistory: List[EncounterStatusHistory] = []
    class_: Coding = Field(alias="class")
    classHistory: List[EncounterClassHistory] = []
    type: List[CodeableConcept] = []
    serviceType: Optional[CodeableConcept] = None
    priority: Optional[CodeableConcept] = None
    subject: Optional[Reference] = None
    episodeOfCare: List[Reference] = []
    basedOn: List[Reference] = []
    participant: List[EncounterParticipant] = []
    appointment: List[Reference] = []
    period: Optional[Period] = None
    length: Optional[Dict[str, Any]] = None
    reasonCode: List[CodeableConcept] = []
    reasonReference: List[Reference] = []
    diagnosis: List[EncounterDiagnosis] = []
    account: List[Reference] = []
    hospitalization: Optional[EncounterHospitalization] = None
    location: List[EncounterLocation] = []
    serviceProvider: Optional[Reference] = None
    partOf: Optional[Reference] = None
    
    class Config:
        populate_by_name = True


# --- AllergyIntolerance Resource ---

class AllergyIntoleranceReaction(BaseModel):
    """Adverse reaction events"""
    substance: Optional[CodeableConcept] = None
    manifestation: List[CodeableConcept] = []
    description: Optional[str] = None
    onset: Optional[str] = None
    severity: Optional[str] = None  # mild | moderate | severe
    exposureRoute: Optional[CodeableConcept] = None
    note: List[Annotation] = []


class FHIRAllergyIntolerance(DomainResource):
    """
    FHIR R4 AllergyIntolerance Resource
    
    Risk of harmful or undesirable physiological response from a substance.
    """
    resourceType: Literal["AllergyIntolerance"] = "AllergyIntolerance"
    
    identifier: List[Identifier] = []
    clinicalStatus: Optional[CodeableConcept] = None
    verificationStatus: Optional[CodeableConcept] = None
    type: Optional[str] = None  # allergy | intolerance
    category: List[str] = []  # food | medication | environment | biologic
    criticality: Optional[str] = None  # low | high | unable-to-assess
    code: Optional[CodeableConcept] = None
    patient: Reference
    encounter: Optional[Reference] = None
    onsetDateTime: Optional[str] = None
    onsetAge: Optional[Dict[str, Any]] = None
    onsetPeriod: Optional[Period] = None
    onsetRange: Optional[Range] = None
    onsetString: Optional[str] = None
    recordedDate: Optional[str] = None
    recorder: Optional[Reference] = None
    asserter: Optional[Reference] = None
    lastOccurrence: Optional[str] = None
    note: List[Annotation] = []
    reaction: List[AllergyIntoleranceReaction] = []


# --- Bundle Resource ---

class BundleLink(BaseModel):
    """Links related to this Bundle"""
    relation: str
    url: str


class BundleEntrySearch(BaseModel):
    """Search related information"""
    mode: Optional[str] = None  # match | include | outcome
    score: Optional[float] = None


class BundleEntryRequest(BaseModel):
    """Additional execution info for transaction/batch"""
    method: str  # GET | HEAD | POST | PUT | DELETE | PATCH
    url: str
    ifNoneMatch: Optional[str] = None
    ifModifiedSince: Optional[str] = None
    ifMatch: Optional[str] = None
    ifNoneExist: Optional[str] = None


class BundleEntryResponse(BaseModel):
    """Results of execution for transaction/batch"""
    status: str
    location: Optional[str] = None
    etag: Optional[str] = None
    lastModified: Optional[str] = None
    outcome: Optional[Dict[str, Any]] = None


class BundleEntry(BaseModel):
    """Entry in the bundle"""
    link: List[BundleLink] = []
    fullUrl: Optional[str] = None
    resource: Optional[Dict[str, Any]] = None
    search: Optional[BundleEntrySearch] = None
    request: Optional[BundleEntryRequest] = None
    response: Optional[BundleEntryResponse] = None


class FHIRBundle(FHIRResource):
    """
    FHIR R4 Bundle Resource
    
    A container for a collection of resources.
    """
    resourceType: Literal["Bundle"] = "Bundle"
    
    identifier: Optional[Identifier] = None
    type: BundleType
    timestamp: Optional[str] = None
    total: Optional[int] = None
    link: List[BundleLink] = []
    entry: List[BundleEntry] = []
    signature: Optional[Dict[str, Any]] = None


# --- OperationOutcome (for errors) ---

class OperationOutcomeIssue(BaseModel):
    """Information about issue occurrence"""
    severity: str  # fatal | error | warning | information
    code: str  # Type of issue
    details: Optional[CodeableConcept] = None
    diagnostics: Optional[str] = None
    location: List[str] = []
    expression: List[str] = []


class FHIROperationOutcome(DomainResource):
    """
    FHIR R4 OperationOutcome Resource
    
    Information about the outcome of an operation.
    """
    resourceType: Literal["OperationOutcome"] = "OperationOutcome"
    
    issue: List[OperationOutcomeIssue] = []
