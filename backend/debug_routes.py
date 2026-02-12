
import sys
import os
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

from main import app

print("DEBUG: Listing all registered routes:")
for route in app.routes:
    if hasattr(route, "methods"):
        print(f"  {route.methods} {route.path}")
    elif hasattr(route, "app"):
        print(f"  MOUNT: {route.path} -> {route.name}")
        try:
            sub_app = route.app
            if hasattr(sub_app, "routes"):
                for sub_route in sub_app.routes:
                    if hasattr(sub_route, "methods"):
                        print(f"    - {sub_route.methods} {route.path}{sub_route.path}")
            else:
                 print(f"    (Sub-app {type(sub_app)} has no .routes)")
        except Exception as e:
            print(f"    (Error inspecting sub-app: {e})")
