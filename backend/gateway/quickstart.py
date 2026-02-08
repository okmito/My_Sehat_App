#!/usr/bin/env python
"""
QUICK START GUIDE - MySehat Gateway

This script demonstrates how to start and verify the gateway.
"""

import subprocess
import sys
import time
from pathlib import Path

# Ensure imports work
sys.path.insert(0, '.')

def print_header(text):
    print(f"\n{'='*60}")
    print(f"  {text}")
    print(f"{'='*60}\n")

def main():
    print_header("MySehat Gateway - Quick Start")

    # Step 1: Verify we're in the right directory
    if not Path("gateway/main.py").exists():
        print("❌ Error: gateway/main.py not found")
        print("   Make sure you're in: c:\\Honey\\Projects\\My_Sehat\\BACKEND")
        sys.exit(1)

    print("✓ Gateway found at: gateway/main.py")

    # Step 2: Verify imports
    print("\n📦 Verifying backend imports...")
    try:
        from gateway.main import gateway_app
        print("✓ Gateway app imported successfully")
    except Exception as e:
        print(f"❌ Import error: {e}")
        sys.exit(1)

    # Step 3: Check key endpoints
    print("\n📍 Checking endpoints...")
    from gateway.main import gateway_app
    routes = [route.path for route in gateway_app.routes]

    key_endpoints = {
        "Diagnostics": "/diagnostics/triage/text",
        "Mental Health": "/mental-health/chat/message",
        "Medicine": "/medicine-reminder/medications/",
    }

    for domain, endpoint in key_endpoints.items():
        if endpoint in routes:
            print(f"  ✓ {domain:15} {endpoint}")
        else:
            print(f"  ❌ {domain:15} {endpoint}")

    # Step 4: Display Swagger info
    print_header("Swagger UI Information")
    print("Once the gateway is running, access:")
    print("  • Swagger UI:  http://localhost:8000/docs")
    print("  • ReDoc:       http://localhost:8000/redoc")
    print("  • OpenAPI:     http://localhost:8000/openapi.json")
    print("  • Health:      http://localhost:8000/health")

    # Step 5: Display run command
    print_header("To Start the Gateway")
    print("Run this command:")
    print("\n  uvicorn gateway.main:gateway_app --reload --port 8000\n")

    # Step 6: Suggest test commands
    print_header("Verification Commands (after starting)")
    print("Test the gateway:")
    print("  # View all endpoints by tag")
    print("  python gateway/test_routes.py")
    print("\n  # Example request (requires running gateway):")
    print("  curl http://localhost:8000/health")

    # Step 7: Suggest sample requests
    print_header("Sample API Requests")
    print("\n1. Diagnostics - Triage Text:")
    print("""
    curl -X POST "http://localhost:8000/diagnostics/triage/text" \\
      -H "Content-Type: application/json" \\
      -d '{"symptoms": "headache and fever"}'
    """)

    print("\n2. Mental Health - Chat Message:")
    print("""
    curl -X POST "http://localhost:8000/mental-health/chat/message" \\
      -H "Content-Type: application/json" \\
      -d '{"user_id": "user123", "message": "I am feeling down"}'
    """)

    print("\n3. Medicine - List Medications:")
    print("""
    curl -X GET "http://localhost:8000/medicine-reminder/medications/" \\
      -H "X-User-Id: user123"
    """)

    print_header("Architecture Overview")
    print("""
    ┌─────────────────────────────────────────────┐
    │    MySehat Gateway (Port 8000)              │
    ├─────────────────────────────────────────────┤
    │                                             │
    │  ┌──────────────┐  ┌──────────────────┐   │
    │  │ Diagnostics  │  │  Mental Health   │   │
    │  │  /diagnostics│  │ /mental-health   │   │
    │  └──────────────┘  └──────────────────┘   │
    │                                             │
    │  ┌────────────────────────────────────┐   │
    │  │     Medicine Reminder               │   │
    │  │  /medicine-reminder                 │   │
    │  └────────────────────────────────────┘   │
    │                                             │
    │           One Swagger UI at /docs          │
    └─────────────────────────────────────────────┘
    """)

    print_header("Next Steps")
    print("""
    1. Make sure all backends are in the workspace
    2. Install dependencies: pip install -r gateway/requirements.txt
    3. Start the gateway: uvicorn gateway.main:gateway_app --reload
    4. Open http://localhost:8000/docs in your browser
    5. Explore and test all endpoints
    """)

    print("\n✅ Ready to go! Start the gateway and visit /docs\n")

if __name__ == "__main__":
    main()
