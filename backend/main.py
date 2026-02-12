from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import os
import sys
from pathlib import Path

# Add backend directory to path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

# --- Import Service Routers/Apps ---
# We import the Apps/Routers to mount them.
# Using 'mount' allows them to keep their internal configuration.
# --- Import Service Routers/Apps ---
# We import the Apps/Routers to mount them.
# Using 'mount' allows them to keep their internal configuration.
from auth_backend.app import app_standalone as auth_app
from diagnostics_backend.diagnostics_app.main import app as diagnostics_app
from diagnostics_backend.diagnostics_app.main import init_db as init_diagnostics_db
from mental_health_backend.mental_health_app.main_dpdp import app as mental_health_app
from mental_health_backend.mental_health_app import db as mental_health_db
from medicine_backend.medicine_app.main import app as medicine_app
from medicine_backend.medicine_app.main import init_db as init_medicine_db
from sos_backend.main import app as sos_app
from sos_backend.database import create_db_and_tables as init_sos_db
from fhir_backend.main import fhir_app
from health_record_backend.main import app as health_records_app
from health_record_backend.main import init_db as init_health_records_db
# Gateway is replaced by this main app

# --- Global Startup/Lifespan ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting MySehat Unified Backend...", flush=True)
    
    # Initialize Databases
    try:
        print("  |-- Initializing Auth DB...")
        from auth_backend.database import init_db as init_auth_db, seed_database as seed_auth_db
        init_auth_db()
        seed_auth_db()
        
        print("  |-- Initializing Diagnostics DB...")
        init_diagnostics_db()
        
        print("  |-- Initializing Mental Health DB...")
        mental_health_db.init_db()
        
        print("  |-- Initializing Medicine DB...")
        init_medicine_db()

        print("  |-- Initializing SOS DB...")
        init_sos_db()

        print("  |-- Initializing Health Records DB...")
        init_health_records_db()
        
    except Exception as e:
        print(f"❌ Database Initialization Failed: {e}", flush=True)
    
    yield
    
    print("🛑 Shutting down MySehat Backend...", flush=True)

# --- Main Application ---
app = FastAPI(
    title="MySehat Unified Platform",
    description="Single-process backend for Render Free Tier optimization.",
    version="2.0.0",
    lifespan=lifespan
)

# CORS (Global)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Tighten this in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Mount Services ---
# We mount each service as a sub-application.
# This preserves their internal routing logic (e.g. /api/v1/...)

print("🔌 Mounting internal services...", flush=True)

# 1. Auth (Port 8001 originally)
app.mount("/auth", auth_app)
print("  ✓ /auth mounted")

# 2. Diagnostics (Port 8002 originally)
app.mount("/diagnostics", diagnostics_app)
print("  ✓ /diagnostics mounted")

# 3. Medicine (Port 8003 originally)
app.mount("/medicine", medicine_app)
print("  ✓ /medicine mounted")

# 4. Mental Health (Port 8004 originally)
app.mount("/mental-health", mental_health_app)
print("  ✓ /mental-health mounted")

# 5. SOS (Port 8005 originally)
app.mount("/sos", sos_app)
print("  ✓ /sos mounted")

# 6. FHIR (Port 8006 originally)
app.mount("/fhir", fhir_app)
print("  ✓ /fhir mounted")

# 7. Health Records (Port 8007 originally)
app.mount("/health-records", health_records_app)
print("  ✓ /health-records mounted")

# 8. Gateway (Optional - generally we replace gateway with this main app)
# But if gateway had specific logic, we might mount it or port it. 
# Looking at start_all_backends, gateway was just a proxy. 
# We don't need to mount gateway if we are THE gateway now.

@app.get("/")
def root():
    return {
        "params": {
            "status": "active",
            "mode": "unified_monolith",
            "render_optimized": True
        },
        "services": [
            "/auth",
            "/diagnostics",
            "/medicine",
            "/mental-health",
            "/sos",
            "/fhir",
            "/health-records"
        ]
    }

@app.get("/health")
def health_check():
    return {"status": "ok"}
