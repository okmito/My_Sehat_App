
import sys
import os
from pathlib import Path

# Add backend directory to sys.path
backend_dir = Path(__file__).resolve().parent
sys.path.insert(0, str(backend_dir))

try:
    from main import app
    print("DEBUG: Checking AUTH routes only:")
    
    found_auth = False
    for route in app.routes:
        path = getattr(route, "path", "")
        if path.startswith("/auth"):
            print(f"MOUNT: {path} -> {getattr(route, 'name', 'unknown')}")
            found_auth = True
            if hasattr(route, "app"):
                sub_app = route.app
                if hasattr(sub_app, "routes"):
                    for sub_route in sub_app.routes:
                        sub_path = getattr(sub_route, "path", "")
                        print(f"  - {getattr(sub_route, 'methods', 'ALL')} {path}{sub_path}")
    
    if not found_auth:
        print("ERROR: No route starts with /auth")

except Exception as e:
    print(f"CRITICAL ERROR: {e}")
    import traceback
    traceback.print_exc()
