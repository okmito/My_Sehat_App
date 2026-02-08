import sys
from pathlib import Path
from fastapi import APIRouter

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from api.api_v1.endpoints import triage

api_router = APIRouter()
api_router.include_router(triage.router, prefix="/triage", tags=["triage"])
