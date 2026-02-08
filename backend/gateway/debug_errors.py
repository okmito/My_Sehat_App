#!/usr/bin/env python
"""
Debug script to capture real errors from gateway endpoints
"""
import sys
import traceback
from pathlib import Path

# Add workspace to path
sys.path.insert(0, str(Path(__file__).parent.parent.resolve()))

print("\n" + "="*70)
print("  GATEWAY ENDPOINT ERROR DIAGNOSTICS")
print("="*70 + "\n")

# Test 1: Try to import and initialize gateway
print("[1/4] Testing gateway import...")
try:
    from gateway.main import gateway_app
    print("  ✓ Gateway imported successfully")
except Exception as e:
    print(f"  ✗ Failed to import gateway:")
    traceback.print_exc()
    sys.exit(1)

# Test 2: Try to call a diagnostics endpoint
print("\n[2/4] Testing Diagnostics endpoint...")
from fastapi.testclient import TestClient

client = TestClient(gateway_app)

try:
    # This should call the triage endpoint with minimal data
    response = client.post(
        "/diagnostics/triage/text",
        json={"symptoms": "test"}
    )
    print(f"  Status: {response.status_code}")
    if response.status_code >= 400:
        print(f"  Response: {response.text}")
        if response.status_code == 500:
            print("\n  ⚠️  FULL ERROR DETAILS:")
            # Try to parse and print JSON error
            try:
                error_data = response.json()
                print(f"  Detail: {error_data.get('detail', 'No detail')}")
            except:
                print(f"  Raw: {response.text}")
except Exception as e:
    print(f"  ✗ Exception during request:")
    traceback.print_exc()

# Test 3: Try to call a mental health endpoint
print("\n[3/4] Testing Mental Health endpoint...")
try:
    response = client.post(
        "/mental-health/chat/message",
        json={"user_id": "test_user", "message": "test message"}
    )
    print(f"  Status: {response.status_code}")
    if response.status_code >= 400:
        print(f"  Response: {response.text[:500]}")
except Exception as e:
    print(f"  ✗ Exception during request:")
    traceback.print_exc()

# Test 4: Try to call a medicine endpoint
print("\n[4/4] Testing Medicine endpoint...")
try:
    response = client.get(
        "/medicine-reminder/medications/",
        headers={"X-User-Id": "test_user"}
    )
    print(f"  Status: {response.status_code}")
    if response.status_code >= 400:
        print(f"  Response: {response.text[:500]}")
except Exception as e:
    print(f"  ✗ Exception during request:")
    traceback.print_exc()

print("\n" + "="*70 + "\n")
