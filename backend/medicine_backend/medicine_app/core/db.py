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


# Models should import Base, not the other way around to avoid circular imports
# and multiple Base instances.
# The main application (main.py) is responsible for importing models 
# to ensure they are registered with Base.metadata before create_all is called.
