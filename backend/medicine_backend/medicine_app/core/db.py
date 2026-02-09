from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import sys
from pathlib import Path

# Add current directory and parent to path
current_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(current_dir))
parent_dir = current_dir.parent
sys.path.insert(0, str(parent_dir))

from config import settings

# SQLite checks same thread by default, we need to disable it for FastAPI
engine = create_engine(
    settings.DATABASE_URL, connect_args={"check_same_thread": False}
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

from sqlalchemy import MetaData

# Define explicit naming convention to ensure consistent constraint names
# This is crucial for migrations and forcing SQLAlchemy to find existing indexes correctly
naming_convention = {
    "ix": "ix_%(column_0_label)s",
    "uq": "uq_%(table_name)s_%(column_0_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s"
}

metadata = MetaData(naming_convention=naming_convention)
Base = declarative_base(metadata=metadata)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# IMPORTANT: Import all models so they are registered with `Base` before
# `Base.metadata.create_all()` is called by the application startup hook.
# Try package-style import first, fall back to local imports used during
# development or when running modules directly.
try:
    # When running as part of the package
    from medicine_backend.medicine_app.models import Medication, MedicationSchedule, Prescription, DoseEvent  # noqa: F401
except ImportError:
    try:
        # When running from the medicine_app folder directly
        from models import Medication, MedicationSchedule, Prescription, DoseEvent  # noqa: F401
    except ImportError:
        # If models cannot be imported here, they will be imported elsewhere
        # before any DB access. We intentionally raise ImportError to surface
        # configuration problems rather than silently ignoring them.
        raise
