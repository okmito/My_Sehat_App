# Unified Backend Entry Point
# Consolidates all services into a single process to prevent OOM on Render
import sys
import os
from pathlib import Path
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# Add current directory to path
BASE_DIR = Path(__file__).resolve().parent
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

# ==========================================
# IMPORT BACKEND APPS
# ==========================================
# We wrap imports in try/except to prevent one failing service from crashing the monolith
# but successfully imported services will be available.

# 1. AUTH BACKEND
try:
    from auth_backend.app import app_standalone as auth_app
    from auth_backend.database import init_db as init_auth_db, seed_database as seed_auth_db
    AUTH_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] Auth Backend unavailable: {e}")
    AUTH_AVAILABLE = False

# 2. DIAGNOSTICS BACKEND
try:
    from diagnostics_backend.diagnostics_app.main import app as diagnostics_app
    from diagnostics_backend.diagnostics_app.main import init_db as init_diagnostics_db
    DIAGNOSTICS_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] Diagnostics Backend unavailable: {e}")
    DIAGNOSTICS_AVAILABLE = False

# 3. MEDICINE BACKEND
try:
    from medicine_backend.medicine_app.main import app as medicine_app
    from medicine_backend.medicine_app.main import init_db as init_medicine_db
    MEDICINE_AVAILABLE = True
except ImportError as e:
    import traceback
    traceback.print_exc()
    print(f"[WARN] Medicine Backend unavailable: {e}")
    MEDICINE_AVAILABLE = False

# 4. MENTAL HEALTH BACKEND
try:
    from mental_health_backend.mental_health_app.main import app as mental_health_app
    from mental_health_backend.mental_health_app import db as mental_health_db
    MENTAL_HEALTH_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] Mental Health Backend unavailable: {e}")
    MENTAL_HEALTH_AVAILABLE = False

# 5. SOS BACKEND
try:
    from sos_backend.main import app as sos_app
    from sos_backend.database import create_db_and_tables as init_sos_db
    SOS_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] SOS Backend unavailable: {e}")
    SOS_AVAILABLE = False

# 6. FHIR BACKEND
try:
    from fhir_backend.main import fhir_app
    FHIR_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] FHIR Backend unavailable: {e}")
    FHIR_AVAILABLE = False

# 7. HEALTH RECORDS BACKEND
try:
    from health_record_backend.main import app as health_records_app
    from health_record_backend.main import init_db as init_health_records_db
    HEALTH_RECORDS_AVAILABLE = True
except ImportError as e:
    print(f"[WARN] Health Records Backend unavailable: {e}")
    HEALTH_RECORDS_AVAILABLE = False


# ==========================================
# LIFESPAN & INITIALIZATION
# ==========================================
@asynccontextmanager
async def lifespan(app: FastAPI):
    print("\n[START] Starting MySehat Unified Monolith...")
    
    # Initialize Databases
    # We must manually trigger init logic since sub-apps don't run their startup events automatically
    
    if AUTH_AVAILABLE:
        try:
            print("[INFO] Initializing Auth DB...")
            init_auth_db()
            seed_auth_db()
        except Exception as e:
            print(f"[ERROR] Auth DB Init Failed: {e}")

    if DIAGNOSTICS_AVAILABLE:
        try:
            print("[INFO] Initializing Diagnostics DB...")
            init_diagnostics_db()
        except Exception as e:
            print(f"[ERROR] Diagnostics DB Init Failed: {e}")

    if MEDICINE_AVAILABLE:
        try:
            print("[INFO] Initializing Medicine DB...")
            init_medicine_db()
        except Exception as e:
            print(f"[ERROR] Medicine DB Init Failed: {e}")
            
    if MENTAL_HEALTH_AVAILABLE:
        try:
            print("[INFO] Initializing Mental Health DB...")
            mental_health_db.init_db()
        except Exception as e:
            print(f"[ERROR] Mental Health DB Init Failed: {e}")

    if SOS_AVAILABLE:
        try:
            print("[INFO] Initializing SOS DB...")
            init_sos_db()
        except Exception as e:
            print(f"[ERROR] SOS DB Init Failed: {e}")

    if HEALTH_RECORDS_AVAILABLE:
        try:
            print("[INFO] Initializing Health Records DB...")
            init_health_records_db()
        except Exception as e:
            print(f"[ERROR] Health Records DB Init Failed: {e}")

    yield
    print("[STOP] Shutting down MySehat Monolith...")


# ==========================================
# MAIN APP DEFINITION
# ==========================================
app = FastAPI(
    title="MySehat Unified API",
    description="Single-process monolithic API for MySehat (Render Optimized)",
    version="2.0.0",
    lifespan=lifespan
)

# Global CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ==========================================
# MOUNT SUB-APPLICATIONS
# ==========================================
# These act as independent apps but run in the same process request loop

if AUTH_AVAILABLE:
    app.mount("/auth", auth_app)
    print("[OK] Mounted /auth")

if DIAGNOSTICS_AVAILABLE:
    app.mount("/diagnostics", diagnostics_app)
    print("[OK] Mounted /diagnostics")

if MEDICINE_AVAILABLE:
    app.mount("/medicine-reminder", medicine_app)
    print("[OK] Mounted /medicine-reminder")

if MENTAL_HEALTH_AVAILABLE:
    app.mount("/mental-health", mental_health_app)
    print("[OK] Mounted /mental-health")

if SOS_AVAILABLE:
    app.mount("/sos", sos_app)
    print("[OK] Mounted /sos")

if FHIR_AVAILABLE:
    app.mount("/fhir", fhir_app)
    print("[OK] Mounted /fhir")

if HEALTH_RECORDS_AVAILABLE:
    app.mount("/health-records", health_records_app)
    print("[OK] Mounted /health-records")

# Mount Static Files if needed (e.g. Medicine uploads)
# Ensure upload directory exists
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")


# ==========================================
# ROOT ENDPOINTS
# ==========================================
@app.get("/")
def root():
    return {
        "message": "MySehat Unified API is running",
        "mode": "Single Process Monolith",
        "services": {
            "auth": "/auth/docs" if AUTH_AVAILABLE else "unavailable",
            "diagnostics": "/diagnostics/docs" if DIAGNOSTICS_AVAILABLE else "unavailable",
            "medicine": "/medicine-reminder/docs" if MEDICINE_AVAILABLE else "unavailable",
            "mental_health": "/mental-health/docs" if MENTAL_HEALTH_AVAILABLE else "unavailable",
            "sos": "/sos/docs" if SOS_AVAILABLE else "unavailable",
            "fhir": "/fhir/docs" if FHIR_AVAILABLE else "unavailable",
            "health_records": "/health-records/docs" if HEALTH_RECORDS_AVAILABLE else "unavailable",
        }
    }

@app.get("/health")
def health():
    return {"status": "healthy", "monolith": True}

# Entry point for local debugging
if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("unified_main:app", host="0.0.0.0", port=port, reload=True)
