import sys
from pathlib import Path
import os

# Add backend to sys.path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

def try_import(name, module_path, import_name):
    print(f"Importing {name}...")
    try:
        # Dynamic import
        import importlib
        mod = importlib.import_module(module_path)
        obj = getattr(mod, import_name)
        print(f"{name} imported successfully.")
        return obj
    except Exception as e:
        print(f"{name} import failed: {e}")
        import traceback
        traceback.print_exc()
        return None

# 1. Auth
try_import("Auth", "auth_backend.app", "app_standalone")
try_import("Auth DB", "auth_backend.database", "init_db")

# 2. Diagnostics
try_import("Diagnostics", "diagnostics_backend.diagnostics_app.main", "app")
try_import("Diagnostics DB", "diagnostics_backend.diagnostics_app.main", "init_db")

# 3. Medicine
try_import("Medicine", "medicine_backend.medicine_app.main", "app")
try_import("Medicine DB", "medicine_backend.medicine_app.main", "init_db")

# 4. Mental Health
try_import("Mental Health", "mental_health_backend.mental_health_app.main", "app")
try_import("Mental Health DB", "mental_health_backend.mental_health_app.db", "init_db")

# 5. SOS
try_import("SOS", "sos_backend.main", "app")
try_import("SOS DB", "sos_backend.database", "create_db_and_tables")

# 6. FHIR
try_import("FHIR", "fhir_backend.main", "fhir_app")

# 7. Health Records
try_import("Health Records", "health_record_backend.main", "app")
try_import("Health Records DB", "health_record_backend.main", "init_db")

print("All imports attempted.")
