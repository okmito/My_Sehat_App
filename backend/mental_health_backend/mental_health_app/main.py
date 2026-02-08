"""
Mental Health AI Backend
========================
This module re-exports the DPDP-compliant version.
All routes are defined in main_dpdp.py with full DPDP compliance.
"""

# Import the DPDP-compliant app
from mental_health_backend.mental_health_app.main_dpdp import app

# Re-export for uvicorn
__all__ = ['app']
