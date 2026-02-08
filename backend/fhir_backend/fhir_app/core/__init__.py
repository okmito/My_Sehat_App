"""
FHIR Backend Core Module
========================

Core functionality for FHIR R4 backend.
"""

from .fhir_mapper import (
    map_user_to_fhir_patient,
    map_symptom_to_fhir_observation,
    map_diagnosis_to_fhir_condition,
    map_medication_to_fhir_medication_request,
    map_lab_report_to_fhir_diagnostic_report,
    map_document_to_fhir_document_reference,
    map_allergy_to_fhir_allergy_intolerance,
    map_emergency_profile_to_fhir_bundle,
)

__all__ = [
    "map_user_to_fhir_patient",
    "map_symptom_to_fhir_observation",
    "map_diagnosis_to_fhir_condition",
    "map_medication_to_fhir_medication_request",
    "map_lab_report_to_fhir_diagnostic_report",
    "map_document_to_fhir_document_reference",
    "map_allergy_to_fhir_allergy_intolerance",
    "map_emergency_profile_to_fhir_bundle",
]
