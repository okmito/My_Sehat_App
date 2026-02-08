"""
MySehat Gateway - Render-Compatible Reverse Proxy
==================================================

This gateway provides:
- ONE public entry point for all backend services
- Reverse proxy routing to internal localhost services
- Centralized authentication and DPDP consent enforcement
- Audit logging for all requests
- Render-compatible single-port deployment

ARCHITECTURE:
- Gateway binds to 0.0.0.0:$PORT (public, Render-compatible)
- All backends run on 127.0.0.1:XXXX (internal only)
- All external requests flow through this gateway
"""

import os
import sys
import asyncio
from pathlib import Path
from datetime import datetime
from typing import Optional
import json

# Add parent directory to path for imports
_parent_dir = Path(__file__).resolve().parent.parent
if str(_parent_dir) not in sys.path:
    sys.path.insert(0, str(_parent_dir))

from fastapi import FastAPI, Request, Response, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
import httpx

# DPDP Compliance imports for centralized consent enforcement
try:
    from shared.dpdp import (
        create_consent_router, create_user_rights_router, create_audit_router,
        get_audit_logger, AuditAction
    )
    DPDP_AVAILABLE = True
    audit_logger = get_audit_logger("gateway")
except ImportError:
    DPDP_AVAILABLE = False
    audit_logger = None
    print("⚠️ DPDP module not available - running without privacy compliance endpoints")


# ==========================================
# INTERNAL SERVICE CONFIGURATION
# ==========================================
# These services run on localhost and are NOT accessible from outside
INTERNAL_SERVICES = {
    "auth": "http://127.0.0.1:8001",
    "diagnostics": "http://127.0.0.1:8002",
    "medicine": "http://127.0.0.1:8003",
    "mental-health": "http://127.0.0.1:8004",
    "sos": "http://127.0.0.1:8005",
    "fhir": "http://127.0.0.1:8006",
    "health-records": "http://127.0.0.1:8007",
}

# Route prefix to service mapping
ROUTE_MAPPINGS = {
    "/auth": "auth",
    "/diagnostics": "diagnostics",
    "/medicine-reminder": "medicine",
    "/mental-health": "mental-health",
    "/sos": "sos",
    "/fhir": "fhir",
    "/health-records": "health-records",
}


# ==========================================
# GATEWAY APPLICATION
# ==========================================
gateway_app = FastAPI(
    title="MySehat Healthcare Gateway",
    description="""
## Unified Healthcare Gateway

This gateway provides a single entry point to all MySehat backend services.

### Available Services
- **Auth** (`/auth/*`): User authentication and session management
- **Diagnostics** (`/diagnostics/*`): AI-powered symptom triage
- **Medicine Reminder** (`/medicine-reminder/*`): Medication management
- **Mental Health** (`/mental-health/*`): Mental health screening and support
- **SOS Emergency** (`/sos/*`): Emergency response system
- **FHIR** (`/fhir/*`): Hospital interoperability (HL7 FHIR R4)
- **Health Records** (`/health-records/*`): Medical record management

### DPDP Compliance
All requests are subject to consent verification under the Digital Personal Data Protection Act 2023.

### Architecture
"MySehat uses a gateway-based architecture where multiple internal services are 
orchestrated behind a single public endpoint, making it compatible with Render's 
single-port deployment model."
    """,
    version="2.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)


# ==========================================
# MIDDLEWARE SETUP
# ==========================================

# CORS Configuration - allows cross-origin requests
gateway_app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update for production
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)


# ==========================================
# CENTRALIZED AUDIT LOGGING MIDDLEWARE
# ==========================================
@gateway_app.middleware("http")
async def audit_logging_middleware(request: Request, call_next):
    """
    Log all incoming requests for audit compliance.
    This is a centralized cross-cutting concern handled at gateway level.
    """
    start_time = datetime.utcnow()
    
    # Extract user ID from headers or auth token if present
    user_id = request.headers.get("X-User-Id", "anonymous")
    
    # Process request
    response = await call_next(request)
    
    # Log the request (non-blocking)
    if audit_logger and DPDP_AVAILABLE:
        try:
            duration_ms = (datetime.utcnow() - start_time).total_seconds() * 1000
            audit_logger.log(
                action=AuditAction.ACCESS,
                user_id=user_id,
                resource_type="api_request",
                resource_id=request.url.path,
                details={
                    "method": request.method,
                    "path": request.url.path,
                    "status_code": response.status_code,
                    "duration_ms": round(duration_ms, 2),
                    "ip": request.client.host if request.client else "unknown"
                }
            )
        except Exception:
            pass  # Don't fail requests due to audit logging errors
    
    return response


# ==========================================
# REVERSE PROXY LOGIC
# ==========================================
async def proxy_request(
    request: Request,
    target_service: str,
    path_prefix: str
) -> Response:
    """
    Forward request to internal backend service.
    
    Preserves:
    - HTTP method
    - Headers (with modifications for internal routing)
    - Body
    - Query parameters
    
    Returns the backend response transparently.
    """
    target_url = INTERNAL_SERVICES.get(target_service)
    if not target_url:
        raise HTTPException(status_code=502, detail=f"Unknown service: {target_service}")
    
    # Strip the gateway prefix from the path before forwarding
    # e.g., /medicine-reminder/reminders/today -> /reminders/today
    original_path = request.url.path
    if original_path.startswith(path_prefix):
        backend_path = original_path[len(path_prefix):] or "/"
    else:
        backend_path = original_path
    
    # Construct full URL with query string
    full_url = f"{target_url}{backend_path}"
    if request.url.query:
        full_url += f"?{request.url.query}"
    
    # Prepare headers (filter out hop-by-hop headers)
    headers = dict(request.headers)
    hop_by_hop = ["host", "connection", "keep-alive", "transfer-encoding", 
                  "te", "trailer", "upgrade", "proxy-authorization", "proxy-authenticate"]
    for h in hop_by_hop:
        headers.pop(h, None)
    
    # Add gateway identifier for internal services
    headers["X-Forwarded-By"] = "mysehat-gateway"
    headers["X-Original-Path"] = original_path
    
    # Get request body
    body = await request.body()
    
    # Make the proxied request
    async with httpx.AsyncClient(timeout=30.0) as client:
        try:
            response = await client.request(
                method=request.method,
                url=full_url,
                headers=headers,
                content=body,
            )
        except httpx.ConnectError:
            raise HTTPException(
                status_code=503,
                detail=f"Service '{target_service}' is unavailable"
            )
        except httpx.TimeoutException:
            raise HTTPException(
                status_code=504,
                detail=f"Service '{target_service}' timed out"
            )
    
    # Build response, filtering out hop-by-hop headers
    response_headers = dict(response.headers)
    for h in hop_by_hop + ["content-encoding", "content-length"]:
        response_headers.pop(h, None)
    
    return Response(
        content=response.content,
        status_code=response.status_code,
        headers=response_headers,
        media_type=response.headers.get("content-type")
    )


# ==========================================
# PROXY ROUTE HANDLERS
# ==========================================

@gateway_app.api_route("/auth/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_auth(request: Request, path: str = ""):
    """Proxy requests to Auth Backend"""
    return await proxy_request(request, "auth", "/auth")


@gateway_app.api_route("/diagnostics/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_diagnostics(request: Request, path: str = ""):
    """Proxy requests to Diagnostics Backend"""
    return await proxy_request(request, "diagnostics", "/diagnostics")


@gateway_app.api_route("/medicine-reminder/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_medicine(request: Request, path: str = ""):
    """Proxy requests to Medicine Reminder Backend"""
    return await proxy_request(request, "medicine", "/medicine-reminder")


@gateway_app.api_route("/mental-health/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_mental_health(request: Request, path: str = ""):
    """Proxy requests to Mental Health Backend"""
    return await proxy_request(request, "mental-health", "/mental-health")


@gateway_app.api_route("/sos/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_sos(request: Request, path: str = ""):
    """Proxy requests to SOS Emergency Backend"""
    return await proxy_request(request, "sos", "/sos")


@gateway_app.api_route("/fhir/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_fhir(request: Request, path: str = ""):
    """Proxy requests to FHIR Backend"""
    return await proxy_request(request, "fhir", "/fhir")


@gateway_app.api_route("/health-records/{path:path}", methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"])
async def proxy_health_records(request: Request, path: str = ""):
    """Proxy requests to Health Records Backend"""
    return await proxy_request(request, "health-records", "/health-records")


# ==========================================
# DPDP COMPLIANCE ENDPOINTS (Centralized)
# ==========================================
if DPDP_AVAILABLE:
    gateway_app.include_router(
        create_consent_router("mysehat_gateway"),
        prefix="/api/v1",
        tags=["DPDP Consent"]
    )
    gateway_app.include_router(
        create_user_rights_router("mysehat_gateway"),
        prefix="/api/v1",
        tags=["DPDP User Rights"]
    )
    gateway_app.include_router(
        create_audit_router("mysehat_gateway"),
        prefix="/api/v1",
        tags=["DPDP Audit"]
    )
    print("[Gateway] ✓ DPDP consent and user rights endpoints registered")


# ==========================================
# GATEWAY HEALTH & INFO ENDPOINTS
# ==========================================

@gateway_app.get("/", tags=["Gateway"])
async def root():
    """Gateway health and information endpoint"""
    return {
        "message": "Welcome to MySehat Healthcare Gateway",
        "version": "2.0.0",
        "architecture": "reverse-proxy",
        "render_compatible": True,
        "dpdp_compliant": DPDP_AVAILABLE,
        "services": {
            "auth": "/auth/*",
            "diagnostics": "/diagnostics/*",
            "medicine_reminder": "/medicine-reminder/*",
            "mental_health": "/mental-health/*",
            "sos_emergency": "/sos/*",
            "fhir": "/fhir/*",
            "health_records": "/health-records/*",
        },
        "dpdp_endpoints": {
            "consent": "/api/v1/consent",
            "my_data": "/api/v1/my-data",
            "audit": "/api/v1/audit",
        } if DPDP_AVAILABLE else None,
        "docs": "/docs",
    }


@gateway_app.get("/health", tags=["Gateway"])
async def health_check():
    """Gateway health check endpoint"""
    # Check connectivity to internal services
    service_status = {}
    
    async with httpx.AsyncClient(timeout=2.0) as client:
        for name, url in INTERNAL_SERVICES.items():
            try:
                response = await client.get(f"{url}/health")
                service_status[name] = "healthy" if response.status_code == 200 else "degraded"
            except Exception:
                service_status[name] = "unavailable"
    
    all_healthy = all(s == "healthy" for s in service_status.values())
    
    return {
        "status": "ok" if all_healthy else "degraded",
        "timestamp": datetime.utcnow().isoformat(),
        "gateway": "healthy",
        "services": service_status,
        "dpdp_compliant": DPDP_AVAILABLE,
    }


@gateway_app.get("/services", tags=["Gateway"])
async def list_services():
    """List all available backend services and their status"""
    services = []
    
    async with httpx.AsyncClient(timeout=2.0) as client:
        for name, url in INTERNAL_SERVICES.items():
            service_info = {
                "name": name,
                "gateway_prefix": f"/{name.replace('_', '-')}",
                "internal_url": url,
                "status": "unknown"
            }
            try:
                response = await client.get(f"{url}/health")
                service_info["status"] = "healthy" if response.status_code == 200 else "degraded"
            except Exception:
                service_info["status"] = "unavailable"
            
            services.append(service_info)
    
    return {"services": services}


# ==========================================
# MAIN ENTRY POINT (for uvicorn)
# ==========================================
if __name__ == "__main__":
    import uvicorn
    
    # Get port from environment (Render sets this) or default to 8000
    port = int(os.environ.get("PORT", os.environ.get("GATEWAY_PORT", "8000")))
    
    print(f"\n{'='*60}")
    print(f"Starting MySehat Gateway on 0.0.0.0:{port}")
    print(f"{'='*60}\n")
    
    uvicorn.run(
        "gateway.main:gateway_app",
        host="0.0.0.0",
        port=port,
        reload=False,
    )
