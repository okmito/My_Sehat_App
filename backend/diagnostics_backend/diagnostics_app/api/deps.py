import sys
from pathlib import Path
from typing import Generator

# Ensure parent is in path for absolute imports
_parent_dir = Path(__file__).resolve().parent.parent.parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

from diagnostics_backend.diagnostics_app.db.session import SessionLocal

def get_db() -> Generator:
    try:
        db = SessionLocal()
        yield db
    finally:
        db.close()
