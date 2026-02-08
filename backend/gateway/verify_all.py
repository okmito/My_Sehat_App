#!/usr/bin/env python
"""
Complete gateway verification - test all endpoints
"""
import sys
from pathlib import Path

# Add workspace to path
sys.path.insert(0, str(Path(__file__).parent.parent.resolve()))

from fastapi.testclient import TestClient
from gateway.main import gateway_app

client = TestClient(gateway_app)

print("\n" + "="*70)
print("  MYSEHAT GATEWAY - COMPLETE VERIFICATION")
print("="*70 + "\n")

# Test counters
passed = 0
failed = 0

def test_endpoint(name, method, path, **kwargs):
    global passed, failed
    try:
        if method.upper() == "GET":
            response = client.get(path, **kwargs)
        elif method.upper() == "POST":
            response = client.post(path, **kwargs)
        else:
            return
        
        status = response.status_code
        if 200 <= status < 300:
            print(f"  [OK] {name:50} {status}")
            passed += 1
        else:
            print(f"  [FAIL] {name:50} {status}")
            print(f"         Response: {response.text[:100]}")
            failed += 1
    except Exception as e:
        print(f"  [ERROR] {name:50} {str(e)[:50]}")
        failed += 1

print("[1] DIAGNOSTICS ENDPOINTS")
print("-"*70)
test_endpoint(
    "Diagnostics - Triage Text",
    "POST",
    "/diagnostics/triage/text",
    json={"symptoms": "headache and fever"}
)

print("\n[2] MENTAL HEALTH ENDPOINTS")
print("-"*70)
test_endpoint(
    "Mental Health - Chat Message",
    "POST",
    "/mental-health/chat/message",
    json={"user_id": "test_user", "message": "I am feeling down"}
)

test_endpoint(
    "Mental Health - Get Check-in Questions",
    "GET",
    "/mental-health/checkin/today",
    params={"user_id": "test_user"}
)

print("\n[3] MEDICINE REMINDER ENDPOINTS")
print("-"*70)
test_endpoint(
    "Medicine - Get Medications",
    "GET",
    "/medicine-reminder/medications/",
    headers={"X-User-Id": "test_user"}
)

test_endpoint(
    "Medicine - Get Reminders Today",
    "GET",
    "/medicine-reminder/reminders/today",
    headers={"X-User-Id": "test_user"}
)

print("\n[4] GATEWAY ENDPOINTS")
print("-"*70)
test_endpoint(
    "Gateway - Root",
    "GET",
    "/"
)

test_endpoint(
    "Gateway - Health",
    "GET",
    "/health"
)

print("\n" + "="*70)
print(f"  RESULTS: {passed} PASSED, {failed} FAILED")
print("="*70)

if failed == 0:
    print("\n  ✓ ALL ENDPOINTS WORKING\n")
    sys.exit(0)
else:
    print(f"\n  ✗ {failed} ENDPOINT(S) FAILED\n")
    sys.exit(1)
