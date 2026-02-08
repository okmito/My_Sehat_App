"""
FHIR R4 Models Package
======================

This package contains all FHIR R4 Pydantic models for MySehat.
"""

from .fhir_base import (
    FHIRResourceType,
    NarrativeStatus,
    BundleType,
    Coding,
    CodeableConcept,
    Identifier,
    HumanName,
    ContactPoint,
    Address,
    Reference,
    Period,
    Quantity,
    Range,
    Narrative,
    Meta,
    Attachment,
    Annotation,
    FHIRResource,
    DomainResource,
)

from .fhir_resources import (
    # Patient
    FHIRPatient,
    PatientContact,
    PatientCommunication,
    PatientLink,
    
    # Observation
    FHIRObservation,
    ObservationReferenceRange,
    ObservationComponent,
    
    # Condition
    FHIRCondition,
    ConditionStage,
    ConditionEvidence,
    
    # Medication
    FHIRMedication,
    MedicationIngredient,
    MedicationBatch,
    
    # MedicationRequest
    FHIRMedicationRequest,
    MedicationRequestDispenseRequest,
    MedicationRequestSubstitution,
    Dosage,
    
    # DiagnosticReport
    FHIRDiagnosticReport,
    DiagnosticReportMedia,
    
    # DocumentReference
    FHIRDocumentReference,
    DocumentReferenceRelatesTo,
    DocumentReferenceContent,
    DocumentReferenceContext,
    
    # Encounter
    FHIREncounter,
    EncounterStatusHistory,
    EncounterClassHistory,
    EncounterParticipant,
    EncounterDiagnosis,
    EncounterHospitalization,
    EncounterLocation,
    
    # AllergyIntolerance
    FHIRAllergyIntolerance,
    AllergyIntoleranceReaction,
    
    # Bundle
    FHIRBundle,
    BundleLink,
    BundleEntry,
    BundleEntrySearch,
    BundleEntryRequest,
    BundleEntryResponse,
    
    # OperationOutcome
    FHIROperationOutcome,
    OperationOutcomeIssue,
)

__all__ = [
    # Base types
    "FHIRResourceType",
    "NarrativeStatus",
    "BundleType",
    "Coding",
    "CodeableConcept",
    "Identifier",
    "HumanName",
    "ContactPoint",
    "Address",
    "Reference",
    "Period",
    "Quantity",
    "Range",
    "Narrative",
    "Meta",
    "Attachment",
    "Annotation",
    "FHIRResource",
    "DomainResource",
    
    # Patient
    "FHIRPatient",
    "PatientContact",
    "PatientCommunication",
    "PatientLink",
    
    # Observation
    "FHIRObservation",
    "ObservationReferenceRange",
    "ObservationComponent",
    
    # Condition
    "FHIRCondition",
    "ConditionStage",
    "ConditionEvidence",
    
    # Medication
    "FHIRMedication",
    "MedicationIngredient",
    "MedicationBatch",
    
    # MedicationRequest
    "FHIRMedicationRequest",
    "MedicationRequestDispenseRequest",
    "MedicationRequestSubstitution",
    "Dosage",
    
    # DiagnosticReport
    "FHIRDiagnosticReport",
    "DiagnosticReportMedia",
    
    # DocumentReference
    "FHIRDocumentReference",
    "DocumentReferenceRelatesTo",
    "DocumentReferenceContent",
    "DocumentReferenceContext",
    
    # Encounter
    "FHIREncounter",
    "EncounterStatusHistory",
    "EncounterClassHistory",
    "EncounterParticipant",
    "EncounterDiagnosis",
    "EncounterHospitalization",
    "EncounterLocation",
    
    # AllergyIntolerance
    "FHIRAllergyIntolerance",
    "AllergyIntoleranceReaction",
    
    # Bundle
    "FHIRBundle",
    "BundleLink",
    "BundleEntry",
    "BundleEntrySearch",
    "BundleEntryRequest",
    "BundleEntryResponse",
    
    # OperationOutcome
    "FHIROperationOutcome",
    "OperationOutcomeIssue",
]
