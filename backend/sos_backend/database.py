from sqlmodel import SQLModel, create_engine, Session
import os
from pathlib import Path

# Detect Render environment
render_env = os.environ.get("RENDER", None)
if render_env or os.environ.get("PORT"):
    # On Render, use /tmp for writable storage
    sqlite_file_name = "/tmp/sos_backend_v2.db"
else:
    # Local development
    sqlite_file_name = "sos_backend_v2.db"

sqlite_url = f"sqlite:///{sqlite_file_name}"

connect_args = {"check_same_thread": False}
engine = create_engine(sqlite_url, connect_args=connect_args)

def create_db_and_tables():
    """Initialize database tables with error handling."""
    print("[INFO] Initializing SOS Backend database...")
    try:
        # Import all models to register them with SQLModel
        from sos_backend.models import SOSEvent, UserEmergencyProfile
        print("[OK] SOS models imported successfully")
        
        SQLModel.metadata.create_all(engine)
        print(f"[OK] SOS database tables created successfully at: {sqlite_url}")
        
        # List all tables that were created
        from sqlalchemy import inspect
        inspector = inspect(engine)
        tables = inspector.get_table_names()
        print(f"[OK] Available SOS tables: {', '.join(tables)}")
    except Exception as e:
        print(f"[ERROR] Failed to create SOS database tables: {e}")
        raise

def get_session():
    with Session(engine) as session:
        yield session

