"""
Authentication API Router
=========================

Provides REST API endpoints for:
- User signup with preferences and consents
- User login (phone-based with OTP simulation)
- Session management (validate, logout)
- User profile management
- Consent management
"""

import json
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Query, Request
from sqlalchemy.orm import Session, joinedload

from .database import get_db
from .models import (
    User, UserPreferences, UserConsent, AuthToken,
    UserCreate, UserLogin, UserResponse,
    PreferencesCreate, PreferencesResponse,
    ConsentCreate, ConsentResponse,
    TokenResponse, SignupResponse, ConsentItem
)
from .auth import (
    create_access_token, verify_token, invalidate_token,
    invalidate_all_user_tokens, get_current_user, get_current_user_optional
)

router = APIRouter(tags=["Authentication"])


# ==========================================
# Utility Functions
# ==========================================

def user_to_response(user: User) -> UserResponse:
    """Convert User model to response schema"""
    return UserResponse(
        id=user.id,
        name=user.name,
        phone_number=user.phone_number,
        age=user.age,
        gender=user.gender,
        blood_group=user.blood_group,
        allergies=json.loads(user.allergies) if user.allergies else [],
        conditions=json.loads(user.conditions) if user.conditions else [],
        emergency_contact=user.emergency_contact,
        emergency_phone=user.emergency_phone,
        created_at=user.created_at,
        preferences=PreferencesResponse(
            language=user.preferences.language,
            emergency_enabled=user.preferences.emergency_enabled,
            medicine_reminders=user.preferences.medicine_reminders,
            notification_enabled=user.preferences.notification_enabled,
            dark_mode=user.preferences.dark_mode
        ) if user.preferences else None,
        consents=[
            ConsentResponse(
                id=c.id,
                data_category=c.data_category,
                purpose=c.purpose,
                granted=c.granted,
                consent_text=c.consent_text,
                created_at=c.created_at,
                expires_at=c.expires_at
            ) for c in user.consents
        ]
    )


# ==========================================
# Signup & Login Endpoints
# ==========================================

@router.post("/signup", response_model=SignupResponse, status_code=status.HTTP_201_CREATED)
def signup(
    user_data: UserCreate,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Register a new user with preferences and DPDP consents.
    
    Required consents (must be granted):
    - emergency_sharing
    - health_record_storage
    - ai_symptom_checker
    
    Optional consents:
    - mental_health_processing (default: OFF)
    - medicine_reminders
    
    Returns an access token for immediate login after signup.
    """
    # Check if phone number already exists
    existing = db.query(User).filter(User.phone_number == user_data.phone_number).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Phone number already registered. Please login instead."
        )
    
    # Validate mandatory consents
    mandatory_purposes = ["emergency_sharing", "health_record_storage", "ai_symptom_checker"]
    granted_purposes = [c.purpose for c in user_data.consents if c.granted]
    
    missing = [p for p in mandatory_purposes if p not in granted_purposes]
    if missing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Mandatory consents required: {', '.join(missing)}"
        )
    
    # Create user
    user = User(
        name=user_data.name,
        phone_number=user_data.phone_number,
        age=user_data.age,
        gender=user_data.gender,
        blood_group=user_data.blood_group,
        allergies=json.dumps(user_data.allergies) if user_data.allergies else None,
        conditions=json.dumps(user_data.conditions) if user_data.conditions else None,
        emergency_contact=user_data.emergency_contact,
        emergency_phone=user_data.emergency_phone,
    )
    db.add(user)
    db.flush()  # Get user ID
    
    # Create preferences
    preferences = UserPreferences(
        user_id=user.id,
        language=user_data.language,
        emergency_enabled=user_data.emergency_enabled,
        medicine_reminders=user_data.medicine_reminders,
    )
    db.add(preferences)
    
    # Create consents
    for consent_data in user_data.consents:
        consent = UserConsent(
            user_id=user.id,
            data_category=consent_data.data_category,
            purpose=consent_data.purpose,
            granted=consent_data.granted,
            consent_text=consent_data.consent_text or f"User consented to {consent_data.purpose}",
            ip_address=request.client.host if request.client else None,
        )
        db.add(consent)
    
    db.commit()
    
    # Refresh to get relationships
    db.refresh(user)
    
    # Create access token
    token = create_access_token(
        user_id=user.id,
        db=db,
        device_info=request.headers.get("User-Agent"),
        ip_address=request.client.host if request.client else None
    )
    
    return SignupResponse(
        message="User registered successfully",
        access_token=token,
        token_type="bearer",
        user=user_to_response(user)
    )


@router.post("/login", response_model=TokenResponse)
def login(
    credentials: UserLogin,
    request: Request,
    db: Session = Depends(get_db)
):
    """
    Login with phone number.
    
    For hackathon demo: OTP is always "123456" or can be omitted.
    In production: Implement proper OTP verification via SMS gateway.
    
    Returns an access token for persistent login.
    The token never expires unless explicitly logged out.
    """
    # Find user by phone
    user = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(
        User.phone_number == credentials.phone_number,
        User.is_active == True
    ).first()
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="User not found. Please sign up first."
        )
    
    # For demo: Accept "123456" as valid OTP or allow empty OTP
    if credentials.otp and credentials.otp != "123456":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid OTP. Use '123456' for demo."
        )
    
    # Create access token
    token = create_access_token(
        user_id=user.id,
        db=db,
        device_info=request.headers.get("User-Agent"),
        ip_address=request.client.host if request.client else None
    )
    
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=user_to_response(user)
    )


@router.post("/logout")
def logout(
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Logout current session.
    
    Invalidates the current token. User must login again to get a new token.
    """
    auth_header = request.headers.get("Authorization")
    if auth_header and auth_header.startswith("Bearer "):
        token = auth_header.split(" ")[1]
        invalidate_token(token, db)
    
    return {"message": "Logged out successfully"}


@router.post("/logout-all")
def logout_all(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Logout from all devices.
    
    Invalidates all tokens for the current user.
    """
    count = invalidate_all_user_tokens(user.id, db)
    return {"message": f"Logged out from {count} session(s)"}


# ==========================================
# Session Validation
# ==========================================

@router.get("/validate", response_model=TokenResponse)
def validate_session(
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """
    Validate current session and return user data.
    
    Use this on app startup to check if the stored token is still valid.
    Returns user data if valid, 401 if invalid.
    """
    # Reload user with relationships
    user = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(User.id == user.id).first()
    
    auth_header = request.headers.get("Authorization")
    token = auth_header.split(" ")[1] if auth_header else ""
    
    return TokenResponse(
        access_token=token,
        token_type="bearer",
        user=user_to_response(user)
    )


# ==========================================
# User Profile Endpoints
# ==========================================

@router.get("/me", response_model=UserResponse)
def get_profile(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's profile"""
    user = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(User.id == user.id).first()
    
    return user_to_response(user)


@router.put("/me", response_model=UserResponse)
def update_profile(
    updates: dict,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update current user's profile"""
    allowed_fields = ["name", "age", "gender", "blood_group", "allergies", 
                      "conditions", "emergency_contact", "emergency_phone"]
    
    for field in allowed_fields:
        if field in updates:
            if field in ["allergies", "conditions"]:
                setattr(user, field, json.dumps(updates[field]))
            else:
                setattr(user, field, updates[field])
    
    user.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(user)
    
    user = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(User.id == user.id).first()
    
    return user_to_response(user)


# ==========================================
# Preferences Endpoints
# ==========================================

@router.get("/preferences", response_model=PreferencesResponse)
def get_preferences(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get current user's preferences"""
    prefs = db.query(UserPreferences).filter(
        UserPreferences.user_id == user.id
    ).first()
    
    if not prefs:
        raise HTTPException(status_code=404, detail="Preferences not found")
    
    return PreferencesResponse(
        language=prefs.language,
        emergency_enabled=prefs.emergency_enabled,
        medicine_reminders=prefs.medicine_reminders,
        notification_enabled=prefs.notification_enabled,
        dark_mode=prefs.dark_mode
    )


@router.put("/preferences", response_model=PreferencesResponse)
def update_preferences(
    updates: PreferencesCreate,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update current user's preferences"""
    prefs = db.query(UserPreferences).filter(
        UserPreferences.user_id == user.id
    ).first()
    
    if not prefs:
        prefs = UserPreferences(user_id=user.id)
        db.add(prefs)
    
    for field, value in updates.model_dump(exclude_unset=True).items():
        if value is not None:
            setattr(prefs, field, value)
    
    prefs.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(prefs)
    
    return PreferencesResponse(
        language=prefs.language,
        emergency_enabled=prefs.emergency_enabled,
        medicine_reminders=prefs.medicine_reminders,
        notification_enabled=prefs.notification_enabled,
        dark_mode=prefs.dark_mode
    )


# ==========================================
# Consent Endpoints
# ==========================================

@router.get("/consents", response_model=List[ConsentResponse])
def get_consents(
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all consents for current user"""
    consents = db.query(UserConsent).filter(
        UserConsent.user_id == user.id
    ).all()
    
    return [ConsentResponse(
        id=c.id,
        data_category=c.data_category,
        purpose=c.purpose,
        granted=c.granted,
        consent_text=c.consent_text,
        created_at=c.created_at,
        expires_at=c.expires_at
    ) for c in consents]


@router.put("/consents/{consent_id}", response_model=ConsentResponse)
def update_consent(
    consent_id: int,
    updates: ConsentCreate,
    request: Request,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update a specific consent"""
    consent = db.query(UserConsent).filter(
        UserConsent.id == consent_id,
        UserConsent.user_id == user.id
    ).first()
    
    if not consent:
        raise HTTPException(status_code=404, detail="Consent not found")
    
    # Check if trying to revoke mandatory consent
    mandatory_purposes = ["emergency_sharing", "health_record_storage", "ai_symptom_checker"]
    if consent.purpose in mandatory_purposes and not updates.granted:
        raise HTTPException(
            status_code=400,
            detail=f"Cannot revoke mandatory consent: {consent.purpose}"
        )
    
    consent.granted = updates.granted
    consent.consent_text = updates.consent_text or consent.consent_text
    consent.ip_address = request.client.host if request.client else None
    
    if not updates.granted:
        consent.revoked_at = datetime.utcnow()
    else:
        consent.revoked_at = None
    
    db.commit()
    db.refresh(consent)
    
    return ConsentResponse(
        id=consent.id,
        data_category=consent.data_category,
        purpose=consent.purpose,
        granted=consent.granted,
        consent_text=consent.consent_text,
        created_at=consent.created_at,
        expires_at=consent.expires_at
    )


# ==========================================
# Public Endpoints (Hospital Website)
# ==========================================

@router.get("/users", response_model=List[UserResponse])
def list_users(
    skip: int = 0,
    limit: int = 50,
    db: Session = Depends(get_db)
):
    """
    List all users (for hospital portal).
    
    In production, this should be protected and filtered by consent.
    For hackathon demo, returns all users.
    """
    users = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(User.is_active == True).offset(skip).limit(limit).all()
    
    return [user_to_response(u) for u in users]


@router.get("/users/{user_id}", response_model=UserResponse)
def get_user(
    user_id: int,
    db: Session = Depends(get_db)
):
    """Get a specific user by ID (for hospital portal)"""
    user = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(User.id == user_id, User.is_active == True).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user_to_response(user)


@router.get("/users/phone/{phone_number}", response_model=UserResponse)
def get_user_by_phone(
    phone_number: str,
    db: Session = Depends(get_db)
):
    """Get a user by phone number (for hospital portal)"""
    user = db.query(User).options(
        joinedload(User.preferences),
        joinedload(User.consents)
    ).filter(User.phone_number == phone_number, User.is_active == True).first()
    
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    return user_to_response(user)


# ==========================================
# Health Check
# ==========================================

@router.get("/health")
def health_check():
    """Health check endpoint"""
    return {"status": "ok", "service": "auth"}
