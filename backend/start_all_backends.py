#!/usr/bin/env python3
"""
MySehat - Single Process Monolith Launcher
==========================================

This script launches the unified backend application in a single process.
This resolves memory issues on Render by avoiding overhead of multiple Python processes.
"""
import uvicorn
import os
import sys
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

if __name__ == "__main__":
    # Get port from environment (Render sets this) or default to 8000
    port = int(os.environ.get("PORT", 8000))
    
    print(f"\n{'='*60}")
    print("[START] Starting MySehat Unified Monolith")
    print(f"   Port: {port}")
    print(f"   Mode: Single Process (Memory Optimized)")
    print(f"{'='*60}\n")
    
    # Run uvicorn directly
    # 'unified_main:app' refers to the app object in backend/unified_main.py
    uvicorn.run(
        "unified_main:app",
        host="0.0.0.0",
        port=port,
        reload=False,     # Disable reload in production/start script
        workers=1,        # Logic is async, 1 worker is sufficient for 512MB RAM
        log_level="info"
    )
