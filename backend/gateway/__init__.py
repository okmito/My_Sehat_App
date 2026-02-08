"""
Gateway Application Package

Composes three independent FastAPI backends:
- diagnostics_backend
- mental_health_backend  
- medicine_backend
"""

from gateway.main import gateway_app

__all__ = ["gateway_app"]
