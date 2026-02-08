"""
Start all backend services for My Sehat App - Render Compatible
================================================================

This script starts all internal backend services on localhost ports,
then starts the gateway which proxies requests to them.

RENDER DEPLOYMENT:
- Only the gateway binds to 0.0.0.0:$PORT (public)
- All other services bind to 127.0.0.1:XXXX (internal only)
- This is REQUIRED for Render's single-port deployment model
"""
import subprocess
import sys
import os
import time
import signal
from pathlib import Path

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    print("⚠️  python-dotenv not installed. Install with: pip install python-dotenv")
    print("   Falling back to system environment variables.\n")

# Get the directory where this script is located
BASE_DIR = Path(__file__).parent

# Internal service port mappings (localhost only - NOT accessible externally)
INTERNAL_SERVICES = {
    "auth": {
        "port": 8001,
        "module": "auth_backend.app:app_standalone",
        "name": "Auth Backend"
    },
    "diagnostics": {
        "port": 8002,
        "module": "diagnostics_backend.diagnostics_app.main:app",
        "name": "Diagnostics Backend"
    },
    "medicine": {
        "port": 8003,
        "module": "medicine_backend.medicine_app.main:app",
        "name": "Medicine Backend"
    },
    "mental_health": {
        "port": 8004,
        "module": "mental_health_backend.mental_health_app.main:app",
        "name": "Mental Health Backend"
    },
    "sos": {
        "port": 8005,
        "module": "sos_backend.main:app",
        "name": "SOS Backend"
    },
    "fhir": {
        "port": 8006,
        "module": "fhir_backend.main:fhir_app",
        "name": "FHIR Backend"
    },
    "health_records": {
        "port": 8007,
        "module": "health_record_backend.main:app",
        "name": "Health Records Backend"
    },
}

# Track all running processes for cleanup
running_processes = []


def start_internal_service(service_key: str, config: dict) -> subprocess.Popen:
    """
    Start an internal backend service on localhost (127.0.0.1).
    These services are NOT accessible from outside the machine.
    """
    port = config["port"]
    module = config["module"]
    name = config["name"]
    
    print(f"  Starting {name} on 127.0.0.1:{port}...")
    
    env = os.environ.copy()
    env["PYTHONPATH"] = str(BASE_DIR)
    
    cmd = [
        sys.executable, "-m", "uvicorn",
        module,
        "--host", "127.0.0.1",  # CRITICAL: localhost only, not 0.0.0.0
        "--port", str(port),
        "--log-level", "warning"
    ]
    
    try:
        process = subprocess.Popen(
            cmd,
            env=env,
            cwd=str(BASE_DIR),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        running_processes.append(process)
        return process
    except Exception as e:
        print(f"  ❌ Failed to start {name}: {e}")
        return None


def start_gateway() -> subprocess.Popen:
    """
    Start the gateway service on 0.0.0.0:$PORT.
    This is the ONLY service accessible from outside (Render requirement).
    """
    # Get port from environment (Render sets this) or default to 8000
    port = os.environ.get("PORT", "8000")
    
    print(f"\n{'='*60}")
    print(f"Starting Gateway on 0.0.0.0:{port} (PUBLIC)")
    print(f"{'='*60}\n")
    
    env = os.environ.copy()
    env["PYTHONPATH"] = str(BASE_DIR)
    env["GATEWAY_PORT"] = port
    
    # Check for GROQ API key
    if not env.get('GROQ_API_KEY'):
        print("⚠️  WARNING: GROQ_API_KEY not set - AI features may fail")
        print("   See GROQ_SETUP.md for setup instructions\n")
    
    cmd = [
        sys.executable, "-m", "uvicorn",
        "gateway.main:gateway_app",
        "--host", "0.0.0.0",  # Public: accessible from outside
        "--port", port,
        "--log-level", "info"
    ]
    
    try:
        process = subprocess.Popen(cmd, env=env, cwd=str(BASE_DIR))
        running_processes.append(process)
        return process
    except Exception as e:
        print(f"❌ Failed to start gateway: {e}")
        return None


def cleanup_processes():
    """Terminate all running backend processes"""
    print("\n🛑 Shutting down all services...")
    for proc in running_processes:
        if proc and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                proc.kill()
    print("✅ All services stopped.")


def signal_handler(signum, frame):
    """Handle shutdown signals gracefully"""
    cleanup_processes()
    sys.exit(0)


def main():
    # Register signal handlers for graceful shutdown
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    print(f"\n{'='*60}")
    print("MySehat Multi-Backend Orchestrator")
    print("Render-Compatible Single-Port Architecture")
    print(f"{'='*60}")
    print(f"\nBase directory: {BASE_DIR}")
    print(f"Public port: {os.environ.get('PORT', '8000')}")
    print("\n[1/2] Starting internal services (localhost only)...\n")
    
    # Start all internal services
    for service_key, config in INTERNAL_SERVICES.items():
        process = start_internal_service(service_key, config)
        if not process:
            print(f"⚠️  {config['name']} failed to start - continuing anyway")
    
    # Give services time to initialize
    print("\n⏳ Waiting for internal services to initialize...")
    time.sleep(3)
    
    # Start the gateway (public-facing)
    print("\n[2/2] Starting public gateway...")
    gateway_process = start_gateway()
    
    if not gateway_process:
        print("❌ Gateway failed to start!")
        cleanup_processes()
        return
    
    gateway_port = os.environ.get("PORT", "8000")
    
    print(f"\n{'='*60}")
    print("✅ MySehat Backend Stack Started Successfully!")
    print(f"{'='*60}")
    print("\n📌 Service URLs:")
    print(f"   Gateway (PUBLIC):  http://0.0.0.0:{gateway_port}")
    print(f"   API Docs:          http://localhost:{gateway_port}/docs")
    print(f"   Health Check:      http://localhost:{gateway_port}/health")
    print("\n📌 Internal Services (localhost only):")
    for key, config in INTERNAL_SERVICES.items():
        print(f"   {config['name']:25} → 127.0.0.1:{config['port']}")
    print(f"\n{'='*60}")
    print("Press Ctrl+C to stop all services")
    print(f"{'='*60}\n")
    
    try:
        # Wait for gateway process
        gateway_process.wait()
    except KeyboardInterrupt:
        pass
    finally:
        cleanup_processes()


if __name__ == '__main__':
    main()
