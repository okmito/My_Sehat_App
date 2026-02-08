from diagnostics_backend.diagnostics_app.db.session import engine, SessionLocal
from diagnostics_backend.diagnostics_app.db.base import Base
from diagnostics_backend.diagnostics_app.db.models import TriageSession, TriageMessage
from diagnostics_backend.diagnostics_app.services.session_service import SessionService
from diagnostics_backend.diagnostics_app.models.schemas import SessionCreate, MessageCreate

def test_db_init():
    print("Creating tables...")
    Base.metadata.create_all(bind=engine)
    print("Tables created.")

def test_session_workflow():
    db = SessionLocal()
    service = SessionService(db)
    
    print("Creating triage session...")
    session_in = SessionCreate(language="fr")
    session = service.create_session(session_in)
    print(f"Session created: {session.id}, language: {session.language}")
    
    print("Adding message...")
    msg_in = MessageCreate(sender="user", content="I have a headache")
    service.add_message(session.id, msg_in)
    
    # Verify retrieval
    s = service.get_session(session.id)
    print(f"Retrieved session has {len(s.messages)} messages.")
    assert len(s.messages) > 0
    print("DB Verification Successful!")

if __name__ == "__main__":
    test_db_init()
    test_session_workflow()
