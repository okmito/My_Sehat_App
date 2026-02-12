from fastapi import FastAPI
import sys
from pathlib import Path
import os

BASE_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(BASE_DIR))

print("[DEBUG] Importing Medicine...")
try:
    from medicine_backend.medicine_app.main import app as medicine_app
    MEDICINE_OK = True
    print("[DEBUG] Medicine Imported.")
except Exception as e:
    print(f"[ERROR] Medicine Import Failed: {e}")
    MEDICINE_OK = False

print("[DEBUG] Importing SOS...")
try:
    from sos_backend.main import app as sos_app
    SOS_OK = True
    print("[DEBUG] SOS Imported.")
except Exception as e:
    print(f"[ERROR] SOS Import Failed: {e}")
    import traceback
    traceback.print_exc()
    SOS_OK = False

app = FastAPI()

if MEDICINE_OK:
    print("[DEBUG] Mounting Medicine...")
    app.mount("/medicine", medicine_app)

if SOS_OK:
    print("[DEBUG] Mounting SOS...")
    app.mount("/sos", sos_app)
    print("[OK] SOS Mounted.")

@app.get("/")
def root():
    return {"message": "Debug App"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
