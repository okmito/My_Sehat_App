#!/usr/bin/env python
"""Test script to verify gateway routes and tags"""

import sys
sys.path.insert(0, '.')

from gateway.main import gateway_app
import json

# Get OpenAPI schema
openapi = gateway_app.openapi()

# Print available tags
if 'tags' in openapi:
    print("Available Tags:")
    for tag in openapi['tags']:
        print(f"  - {tag['name']}")
    print()

# Print paths grouped by tag
print("Endpoints by Tag:")
paths = openapi.get('paths', {})
endpoints_by_tag = {}

for path, methods in sorted(paths.items()):
    for method, details in methods.items():
        if isinstance(details, dict) and 'tags' in details:
            tags = details['tags']
            summary = details.get('summary', '')[:60]
            for tag in tags:
                if tag not in endpoints_by_tag:
                    endpoints_by_tag[tag] = []
                endpoints_by_tag[tag].append(f"{method.upper():6} {path:45} {summary}")

for tag in sorted(endpoints_by_tag.keys()):
    print(f"\n{tag}:")
    for endpoint in endpoints_by_tag[tag]:
        print(f"  {endpoint}")

print(f"\n[+] Total endpoints: {len([e for tag in endpoints_by_tag.values() for e in tag])}")
print(f"[+] Total tags: {len(endpoints_by_tag)}")
