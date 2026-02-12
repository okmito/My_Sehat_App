import sys
from pathlib import Path
import os

# Add backend to sys.path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

print("Importing Medicine...")
try:
    from medicine_backend.medicine_app.main import app as medicine_app
    print("Medicine imported.")
except Exception as e:
    print(f"Medicine import failed: {e}")

print("Importing SOS...")
try:
    from sos_backend.main import app as sos_app
    print("SOS imported.")
except Exception as e:
    print(f"SOS import failed: {e}")
    import traceback
    traceback.print_exc()
