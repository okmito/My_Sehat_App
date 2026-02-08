import sys
from pathlib import Path
import uuid
from datetime import datetime
from sqlalchemy import Column, String, Integer, DateTime, Text, JSON, ForeignKey, Boolean
from sqlalchemy.orm import relationship

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from db.base import Base

class TriageSession(Base):
    __tablename__ = "triage_sessions"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    status = Column(String, default="collecting")  # collecting, completed
    language = Column(String, default="en")
    
    # Relationships
    messages = relationship("TriageMessage", back_populates="session", cascade="all, delete-orphan")
    observations = relationship("TriageObservation", back_populates="session", cascade="all, delete-orphan")
    media_assets = relationship("MediaAsset", back_populates="session", cascade="all, delete-orphan")
    output = relationship("TriageOutput", uselist=False, back_populates="session", cascade="all, delete-orphan")

class TriageMessage(Base):
    __tablename__ = "triage_messages"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String, ForeignKey("triage_sessions.id"))
    sender = Column(String)  # user, ai
    content = Column(Text)
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("TriageSession", back_populates="messages")

class TriageObservation(Base):
    __tablename__ = "triage_observations"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String, ForeignKey("triage_sessions.id"))
    source = Column(String)  # vision, text
    observation_data = Column(JSON)  # { "body_part": "arm", "symptom": "rash" }
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("TriageSession", back_populates="observations")

class MediaAsset(Base):
    __tablename__ = "media_assets"

    id = Column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = Column(String, ForeignKey("triage_sessions.id"))
    file_path = Column(String)
    media_type = Column(String) # image, etc
    processed = Column(Boolean, default=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("TriageSession", back_populates="media_assets")

class TriageOutput(Base):
    __tablename__ = "triage_outputs"

    id = Column(Integer, primary_key=True, index=True)
    session_id = Column(String, ForeignKey("triage_sessions.id"))
    structured_data = Column(JSON)
    created_at = Column(DateTime, default=datetime.utcnow)

    session = relationship("TriageSession", back_populates="output")
