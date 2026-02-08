from contextlib import asynccontextmanager
from typing import List, Optional
from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from sqlmodel import Session, select
from datetime import datetime, timedelta
import random

import sys
from pathlib import Path

# Add parent directory to path for imports
parent_dir = Path(__file__).parent.parent
if str(parent_dir) not in sys.path:
    sys.path.insert(0, str(parent_dir))

try:
    from sos_backend.database import create_db_and_tables, get_session
    from sos_backend.models import SOSEvent, SOSStatus, SOSCreate, UserEmergencyProfile
except ImportError:
    try:
        from .database import create_db_and_tables, get_session
        from .models import SOSEvent, SOSStatus, SOSCreate, UserEmergencyProfile
    except ImportError:
        from database import create_db_and_tables, get_session
        from models import SOSEvent, SOSStatus, SOSCreate, UserEmergencyProfile

# DPDP Compliance imports
try:
    from shared.dpdp import (
        ConsentEngine, ConsentCheck, ConsentCreate, DataCategory, Purpose, GrantedTo,
        AuditLogger, AuditAction, AuditLogEntry,
        EmergencyDataPacket, EmergencyAccessConfig, get_emergency_data_packet, DEFAULT_EMERGENCY_CONFIG,
        get_consent_engine, get_audit_logger,
        add_dpdp_middleware, create_consent_router, create_user_rights_router, create_audit_router
    )
    DPDP_AVAILABLE = True
except ImportError:
    DPDP_AVAILABLE = False
    print("⚠️ DPDP module not available - running without privacy compliance")

@asynccontextmanager
async def lifespan(app: FastAPI):
    create_db_and_tables()
    yield

app = FastAPI(lifespan=lifespan, title="SOS Backend Module - DPDP Compliant")

# CORS Configuration for cross-origin requests from hospital website
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Update for production
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["*"],
)

# Add DPDP Middleware and Consent APIs
if DPDP_AVAILABLE:
    # Add middleware (Port 8000 = SOS Emergency)
    add_dpdp_middleware(app, service_port=8000)
    
    # Add consent management APIs
    app.include_router(create_consent_router("sos_backend"), prefix="/api/v1")
    app.include_router(create_user_rights_router("sos_backend"), prefix="/api/v1")
    app.include_router(create_audit_router("sos_backend"), prefix="/api/v1")

# Initialize DPDP components
if DPDP_AVAILABLE:
    consent_engine = get_consent_engine()
    audit_logger = get_audit_logger("sos_backend")

@app.get("/")
def read_root():
    return {
        "message": "SOS Backend Module is running. Go to /docs for Swagger UI.",
        "dpdp_compliant": DPDP_AVAILABLE
    }

# Mock Service: Assign Ambulance
def mock_assign_ambulance(sos_id: int, session: Session):
    # Simulate a delay or process finding an ambulance
    # For hackathon demo, we just update it to "Acknowledged" then "OnTheWay"
    
    # Re-fetch event
    sos_event = session.get(SOSEvent, sos_id)
    if sos_event:
        sos_event.status = SOSStatus.ACKNOWLEDGED
        sos_event.assigned_ambulance_id = f"AMB-{random.randint(100, 999)}"
        session.add(sos_event)
        session.commit()

from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from fastapi import Request

templates = Jinja2Templates(directory="sos_backend/templates")

@app.get("/map", response_class=HTMLResponse)
def map_view(request: Request):
    return templates.TemplateResponse("map.html", {"request": request})

import requests
import json
# Models already imported at top

# Import additional models
try:
    from sos_backend.models import UserEmergencyProfile, EmergencyProfileUpdate, EmergencyDataResponse
except ImportError:
    try:
        from .models import UserEmergencyProfile, EmergencyProfileUpdate, EmergencyDataResponse
    except ImportError:
        from models import UserEmergencyProfile, EmergencyProfileUpdate, EmergencyDataResponse


# ============================================================================
# DPDP COMPLIANT ENDPOINTS
# ============================================================================

@app.post("/sos/", response_model=SOSEvent)
def create_sos(sos_input: SOSCreate, background_tasks: BackgroundTasks, session: Session = Depends(get_session)):
    """
    Create SOS emergency event.
    DPDP: Grants emergency consent for minimal data sharing.
    """
    # 1. Create SOSEvent from input
    sos_event = SOSEvent.model_validate(sos_input)
    
    session.add(sos_event)
    session.commit()
    session.refresh(sos_event)
    
    # DPDP: Grant emergency consent (time-limited, minimal data)
    if DPDP_AVAILABLE:
        try:
            consent_result = consent_engine.grant_emergency_consent(
                user_id=sos_input.user_id,
                emergency_id=str(sos_event.id),
                responder_id="ambulance_service"
            )
            sos_event.emergency_consent_id = consent_result.id
            sos_event.consent_expires_at = datetime.utcnow() + timedelta(hours=24)
            
            # Log emergency access
            audit_logger.log_emergency_access(
                user_id=sos_input.user_id,
                emergency_id=str(sos_event.id),
                responder_id="ambulance_service",
                data_accessed=["location", "emergency_type", "user_id"],
                justification=f"Emergency SOS triggered: {sos_input.emergency_type}"
            )
        except Exception as e:
            print(f"DPDP consent error: {e}")
    
    # 2. Mock Ambulance Assignment
    sos_event.status = SOSStatus.ACKNOWLEDGED
    sos_event.assigned_ambulance_id = f"AMB-{random.randint(100, 999)}"
    sos_event.data_shared_to = sos_event.assigned_ambulance_id
    
    # Init ambulance nearby (random offset approx 2-3km to allow effective routing demo)
    # 0.02 deg is roughly 2.2km
    sos_event.ambulance_lat = sos_event.latitude + random.uniform(-0.02, 0.02)
    sos_event.ambulance_lon = sos_event.longitude + random.uniform(-0.02, 0.02)
    
    # 3. Fetch OSRM Route
    try:
        url = f"http://router.project-osrm.org/route/v1/driving/{sos_event.ambulance_lon},{sos_event.ambulance_lat};{sos_event.longitude},{sos_event.latitude}?overview=full&geometries=geojson"
        r = requests.get(url, timeout=5)
        if r.status_code == 200:
            data = r.json()
            if "routes" in data and len(data["routes"]) > 0:
                coords = data["routes"][0]["geometry"]["coordinates"] 
                # OSRM returns [lon, lat]
                sos_event.route_coords = json.dumps(coords)
                sos_event.route_progress = 0
                
                # Set initial position to start of route
                sos_event.ambulance_lon = coords[0][0]
                sos_event.ambulance_lat = coords[0][1]
    except Exception as e:
        print(f"OSRM Error: {e}")
    
    session.add(sos_event)
    session.commit()
    session.refresh(sos_event)

    return sos_event


@app.get("/sos/active", response_model=List[SOSEvent])
def get_active_sos_events(session: Session = Depends(get_session)):
    """
    Get all active SOS events (for hospital/responders).
    Returns events that are not yet RESOLVED or CANCELLED.
    DPDP: Only returns events with valid emergency consent.
    """
    active_statuses = [SOSStatus.TRIGGERED, SOSStatus.ACKNOWLEDGED, SOSStatus.ON_THE_WAY]
    statement = select(SOSEvent).where(SOSEvent.status.in_(active_statuses))
    results = session.exec(statement).all()
    
    # Filter out events with expired consent (DPDP compliance)
    valid_events = []
    for event in results:
        if event.consent_expires_at:
            if datetime.utcnow() < event.consent_expires_at:
                valid_events.append(event)
        else:
            valid_events.append(event)
    
    return valid_events


@app.get("/sos/{sos_id}", response_model=SOSEvent)
def get_sos_status(sos_id: int, session: Session = Depends(get_session)):
    sos_event = session.get(SOSEvent, sos_id)
    if not sos_event:
        raise HTTPException(status_code=404, detail="SOS Event not found")
    
    now = datetime.utcnow()
    elapsed = (now - sos_event.timestamp).total_seconds()
    
    changed = False
    
    # Simulate movement if OnTheWay
    if sos_event.status == SOSStatus.ON_THE_WAY:
        if sos_event.route_coords:
            # Route based movement
            coords = json.loads(sos_event.route_coords)
            total_points = len(coords)
            
            # Dynamic speed: Attempt to finish route in ~30 updates (approx 1 min if polling every 2s)
            speed = max(1, int(total_points / 30))
            
            new_progress = sos_event.route_progress + speed
            
            if new_progress >= total_points - 1:
                sos_event.route_progress = total_points - 1
                sos_event.status = SOSStatus.RESOLVED # Arrived
                sos_event.ambulance_lon = coords[-1][0]
                sos_event.ambulance_lat = coords[-1][1]
                changed = True
                
                # DPDP: Auto-revoke emergency consent when resolved
                if DPDP_AVAILABLE and sos_event.emergency_consent_id:
                    try:
                        consent_engine.revoke_emergency_consent(
                            user_id=sos_event.user_id,
                            emergency_id=str(sos_event.id)
                        )
                        audit_logger.log(AuditLogEntry(
                            user_id=sos_event.user_id,
                            action=AuditAction.EMERGENCY_END,
                            resource_type="sos_event",
                            resource_id=str(sos_event.id),
                            purpose="emergency",
                            details={"status": "resolved", "consent_revoked": True}
                        ))
                    except Exception as e:
                        print(f"DPDP revoke error: {e}")
            else:
                sos_event.route_progress = new_progress
                sos_event.ambulance_lon = coords[new_progress][0]
                sos_event.ambulance_lat = coords[new_progress][1]
                changed = True
        elif sos_event.ambulance_lat and sos_event.ambulance_lon:
             # Fallback Linear Movement (if OSRM failed)
             # Move 5% closer to user every request
            sos_event.ambulance_lat += (sos_event.latitude - sos_event.ambulance_lat) * 0.05
            sos_event.ambulance_lon += (sos_event.longitude - sos_event.ambulance_lon) * 0.05
            changed = True

    if sos_event.status == SOSStatus.ACKNOWLEDGED and elapsed > 3: 
        sos_event.status = SOSStatus.ON_THE_WAY
        changed = True
    elif sos_event.status == SOSStatus.ON_THE_WAY and not sos_event.route_coords and elapsed > 60: 
        # Fallback timeout only if linear movement (give it more time)
        sos_event.status = SOSStatus.RESOLVED
        changed = True
        
    if changed:
        session.add(sos_event)
        session.commit()
        session.refresh(sos_event)
        
    return sos_event


# ============================================================================
# EMERGENCY PROFILE ENDPOINTS (DPDP Compliant)
# ============================================================================

@app.get("/emergency-profile/{user_id}", response_model=UserEmergencyProfile)
def get_emergency_profile(user_id: str, session: Session = Depends(get_session)):
    """
    Get user's emergency profile.
    DPDP: User controls what data is shared during emergencies.
    """
    profile = session.exec(
        select(UserEmergencyProfile).where(UserEmergencyProfile.user_id == user_id)
    ).first()
    
    if not profile:
        # Create default profile
        profile = UserEmergencyProfile(user_id=user_id)
        session.add(profile)
        session.commit()
        session.refresh(profile)
    
    return profile


@app.put("/emergency-profile/{user_id}", response_model=UserEmergencyProfile)
def update_emergency_profile(
    user_id: str, 
    update: EmergencyProfileUpdate, 
    session: Session = Depends(get_session)
):
    """
    Update user's emergency profile and sharing preferences.
    DPDP: User controls exactly what data is shared during emergencies.
    """
    profile = session.exec(
        select(UserEmergencyProfile).where(UserEmergencyProfile.user_id == user_id)
    ).first()
    
    if not profile:
        profile = UserEmergencyProfile(user_id=user_id)
    
    # Update fields
    update_data = update.model_dump(exclude_unset=True)
    
    # Handle list fields (store as JSON)
    for field in ['allergies', 'chronic_conditions', 'current_medications', 'emergency_contacts']:
        if field in update_data and update_data[field] is not None:
            update_data[field] = json.dumps(update_data[field])
    
    for key, value in update_data.items():
        setattr(profile, key, value)
    
    profile.updated_at = datetime.utcnow()
    
    session.add(profile)
    session.commit()
    session.refresh(profile)
    
    # DPDP: Log profile update
    if DPDP_AVAILABLE:
        audit_logger.log_data_access(
            user_id=user_id,
            action=AuditAction.UPDATE,
            resource_type="emergency_profile",
            resource_id=str(profile.id),
            purpose="user_profile_management"
        )
    
    return profile


@app.get("/sos/{sos_id}/emergency-data", response_model=EmergencyDataResponse)
def get_emergency_data_for_responders(
    sos_id: int,
    responder_id: str,
    session: Session = Depends(get_session)
):
    """
    Get minimal emergency data for responders.
    DPDP: Only returns data user has opted to share, with consent verification.
    """
    sos_event = session.get(SOSEvent, sos_id)
    if not sos_event:
        raise HTTPException(status_code=404, detail="SOS Event not found")
    
    # DPDP: Verify emergency consent is still valid
    if DPDP_AVAILABLE:
        if sos_event.consent_expires_at and datetime.utcnow() > sos_event.consent_expires_at:
            audit_logger.log_access_denied(
                user_id=sos_event.user_id,
                resource_type="emergency_data",
                reason="Emergency consent expired"
            )
            raise HTTPException(status_code=403, detail="Emergency consent has expired")
        
        # Log this data access
        audit_logger.log_emergency_access(
            user_id=sos_event.user_id,
            emergency_id=str(sos_id),
            responder_id=responder_id,
            data_accessed=["emergency_profile", "location", "medical_data"],
            justification=f"Responder {responder_id} accessed emergency data"
        )
    
    # Get user's emergency profile
    profile = session.exec(
        select(UserEmergencyProfile).where(UserEmergencyProfile.user_id == sos_event.user_id)
    ).first()
    
    # Build response with ONLY opted-in data
    response = EmergencyDataResponse(
        user_id=sos_event.user_id,
        latitude=sos_event.latitude,
        longitude=sos_event.longitude,
        emergency_type=sos_event.emergency_type,
        status=sos_event.status.value,
        consent_id=sos_event.emergency_consent_id,
        expires_at=sos_event.consent_expires_at
    )
    
    if profile:
        # Only include data user has opted to share
        if profile.share_name:
            response.name = profile.name
        if profile.share_age:
            response.age = profile.age
        if profile.share_blood_group:
            response.blood_group = profile.blood_group
        if profile.share_allergies and profile.allergies:
            response.allergies = json.loads(profile.allergies)
        if profile.share_chronic_conditions and profile.chronic_conditions:
            response.chronic_conditions = json.loads(profile.chronic_conditions)
        if profile.share_current_medications and profile.current_medications:
            response.current_medications = json.loads(profile.current_medications)
        if profile.share_emergency_contacts and profile.emergency_contacts:
            response.emergency_contacts = json.loads(profile.emergency_contacts)
        if profile.share_organ_donor_status:
            response.organ_donor = profile.organ_donor
        if profile.share_insurance_info:
            response.insurance_provider = profile.insurance_provider
            response.insurance_id = profile.insurance_id
    
    return response


@app.get("/sos/user/{user_id}", response_model=List[SOSEvent])
def get_user_sos_history(user_id: str, session: Session = Depends(get_session)):
    """
    Get user's SOS history.
    DPDP: User can view their own emergency history.
    """
    if DPDP_AVAILABLE:
        audit_logger.log_data_access(
            user_id=user_id,
            action=AuditAction.READ,
            resource_type="sos_history",
            purpose="user_data_access"
        )
    
    statement = select(SOSEvent).where(SOSEvent.user_id == user_id)
    results = session.exec(statement).all()
    return results


@app.delete("/sos/user/{user_id}/history")
def delete_user_sos_history(user_id: str, session: Session = Depends(get_session)):
    """
    Delete user's SOS history (Right to Erasure).
    DPDP: User can request deletion of their emergency data.
    """
    statement = select(SOSEvent).where(SOSEvent.user_id == user_id)
    events = session.exec(statement).all()
    
    count = len(events)
    for event in events:
        session.delete(event)
    
    # Also delete emergency profile
    profile = session.exec(
        select(UserEmergencyProfile).where(UserEmergencyProfile.user_id == user_id)
    ).first()
    if profile:
        session.delete(profile)
    
    session.commit()
    
    # DPDP: Log erasure
    if DPDP_AVAILABLE:
        audit_logger.log(AuditLogEntry(
            user_id=user_id,
            action=AuditAction.DATA_ERASURE,
            resource_type="sos_all_data",
            purpose="right_to_erasure",
            details={"events_deleted": count, "profile_deleted": profile is not None}
        ))
    
    return {"message": f"Deleted {count} SOS events and emergency profile", "dpdp_compliant": True}


@app.get("/hospitals/nearby")
def get_nearby_hospitals(lat: float, lon: float):
    # Mock data
    return [
        {"id": 1, "name": "City General", "lat": lat + 0.01, "lon": lon + 0.01, "distance_km": 1.2},
        {"id": 2, "name": "St. Marys", "lat": lat - 0.01, "lon": lon - 0.005, "distance_km": 1.5},
        {"id": 3, "name": "Trauma Center", "lat": lat + 0.005, "lon": lon - 0.01, "distance_km": 0.8},
    ]

# For debugging/demo
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
