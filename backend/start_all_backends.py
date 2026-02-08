"""
Start all backend services for My Sehat App
Uses the unified Gateway which includes all services.
"""
import subprocess
import sys
import os
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


def start_gateway():
    """Start the unified gateway that includes all backends"""
    print(f"\n{'='*60}")
    print("Starting MySehat Unified Gateway on port 8000...")
    print(f"Gateway: {BASE_DIR / 'gateway' / 'main.py'}")
    print(f"{'='*60}\n")
    
    env = os.environ.copy()
    
    # Check for GROQ API key
    if not env.get('GROQ_API_KEY'):
        print("⚠️  WARNING: GROQ_API_KEY environment variable not set!")
        print("   Mental Health and Diagnostics AI features may fail")
        print("   See GROQ_SETUP.md for how to set it\n")
    
    cmd = [
        sys.executable,
        str(BASE_DIR / 'gateway' / 'main.py')
    ]
    
    try:
        return subprocess.Popen(cmd, env=env, cwd=str(BASE_DIR))
    except Exception as e:
        print(f"Error starting gateway: {e}")
        return None


def main():
    print("Starting MySehat Unified Gateway...")
    print(f"Base directory: {BASE_DIR}\n")
    print("The gateway includes ALL backend services:")
    print("  - Auth (login/signup)")
    print("  - SOS Emergency")
    print("  - Diagnostics")
    print("  - Mental Health")
    print("  - Medicine Reminders")
    print("  - Health Records")
    print("  - FHIR R4 (Hospital interop)")
    print("  - DPDP Consent Management\n")
    
    process = None
    
    try:
        process = start_gateway()
        
        if not process:
            print("❌ Failed to start gateway!")
            return
        
        print(f"\n{'='*60}")
        print("✅ Gateway started successfully!")
        print("   API Docs: http://localhost:8000/docs")
        print("   Health:   http://localhost:8000/")
        print("\nPress Ctrl+C to stop the gateway")
        print(f"{'='*60}\n")
        
        # Wait for the process
        process.wait()
            
    except KeyboardInterrupt:
        print("\n\nStopping gateway...")
        if process:
            process.terminate()
        print("Gateway stopped.")

if __name__ == '__main__':
    main()
