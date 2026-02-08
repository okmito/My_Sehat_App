#!/usr/bin/env python
"""Test script to verify gateway starts correctly"""

import sys
sys.path.insert(0, '.')

from gateway.main import gateway_app

# Verify app is created
assert gateway_app is not None
print("✓ Gateway app created successfully")

# Verify title
assert gateway_app.title == "MySehat Integrated Healthcare Gateway"
print(f"✓ App title: {gateway_app.title}")

# Verify routes are mounted
routes = [route.path for route in gateway_app.routes]
print(f"✓ Total routes: {len(routes)}")

# Verify key endpoints exist
key_endpoints = [
    "/diagnostics/triage/text",
    "/mental-health/chat/message",
    "/medicine-reminder/medications/",
]

for endpoint in key_endpoints:
    if endpoint in routes:
        print(f"✓ Found endpoint: {endpoint}")
    else:
        print(f"✗ Missing endpoint: {endpoint}")
        sys.exit(1)

# Get OpenAPI schema to verify no errors
openapi = gateway_app.openapi()
print(f"✓ OpenAPI schema generated successfully")

# Count paths
paths = openapi.get('paths', {})
print(f"✓ Total OpenAPI paths: {len(paths)}")

print("\n✅ Gateway validation complete - all checks passed!")
