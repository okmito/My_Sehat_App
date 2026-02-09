import sys
from pathlib import Path
from sqlalchemy.orm import Session
from typing import Optional

# Add backend directory to path (Enforce package imports)
# Path: .../backend
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))

from diagnostics_backend.diagnostics_app.db.models import TriageSession, TriageMessage, TriageObservation
from diagnostics_backend.diagnostics_app.models.schemas import SessionCreate, MessageCreate

class SessionService:
    def __init__(self, db: Session):
        self.db = db

    def create_session(self, session_in: SessionCreate) -> TriageSession:
        db_session = TriageSession(language=session_in.language)
        self.db.add(db_session)
        self.db.commit()
        self.db.refresh(db_session)
        return db_session

    def get_session(self, session_id: str) -> Optional[TriageSession]:
        return self.db.query(TriageSession).filter(TriageSession.id == session_id).first()

    def add_message(self, session_id: str, message_in: MessageCreate) -> TriageMessage:
        db_message = TriageMessage(
            session_id=session_id,
            sender=message_in.sender,
            content=message_in.content
        )
        self.db.add(db_message)
        self.db.commit()
        self.db.refresh(db_message)
        return db_message

    def add_observation(self, session_id: str, source: str, data: dict):
        observation = TriageObservation(
            session_id=session_id,
            source=source,
            observation_data=data
        )
        self.db.add(observation)
        self.db.commit()
