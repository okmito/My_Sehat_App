"""
FHIR API Endpoints
==================

All FHIR R4 endpoints with DPDP consent enforcement.
"""

from . import patient, observation, medication, document, emergency

__all__ = ["patient", "observation", "medication", "document", "emergency"]
