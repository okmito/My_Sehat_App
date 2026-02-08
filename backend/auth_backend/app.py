"""
Auth Backend Standalone Application
====================================

Standalone FastAPI app for running the auth backend as a separate service.
Used by start_all_backends.py for multi-process deployment.
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .router import router as auth_router
from .database import init_db, seed_database

# Create standalone app
app_standalone = FastAPI(
    title="MySehat Auth Backend",
    description="Authentication service for MySehat platform",
    version="1.0.0"
)

# CORS Configuration
app_standalone.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app_standalone.on_event("startup")
def on_startup():
    """Initialize database on startup"""
    init_db()
    seed_database()
    print("[Auth Backend] ✓ Database initialized and seeded")


@app_standalone.get("/")
def root():
    """Health check endpoint"""
    return {"status": "ok", "service": "auth_backend"}


@app_standalone.get("/health")
def health():
    """Health check endpoint"""
    return {"status": "ok", "service": "auth_backend"}


# Include the auth router
app_standalone.include_router(auth_router)
