import sys
import os
from pathlib import Path

# Add backend to sys.path
BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

print("Attempting to import sos_backend.main...")
try:
    from sos_backend.main import app
    print("Successfully imported sos_backend.main")
except Exception as e:
    print(f"Error importing sos_backend.main: {e}")
    import traceback
    traceback.print_exc()
