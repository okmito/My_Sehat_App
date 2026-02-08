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

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
