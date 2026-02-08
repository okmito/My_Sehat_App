"""
Authentication Utilities
========================

Token-based authentication with JWT for persistent login.
Supports both OTP-based and token-based authentication.
"""

import os
import secrets
from datetime import datetime, timedelta
from typing import Optional
import hashlib
import jwt
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session

from .database import get_db
from .models import User, AuthToken

# JWT Configuration
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "mysehat-super-secret-key-change-in-production")
ALGORITHM = "HS256"
# No expiration by default for persistent login
ACCESS_TOKEN_EXPIRE_DAYS = None  # None = never expires

security = HTTPBearer(auto_error=False)


def hash_password(password: str) -> str:
    """Hash a password using SHA256 (simple implementation)"""
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify a password against its hash"""
    return hash_password(plain_password) == hashed_password


def create_access_token(
    user_id: int,
    db: Session,
    expires_delta: Optional[timedelta] = None,
    device_info: Optional[str] = None,
    ip_address: Optional[str] = None
) -> str:
    """
    Create a new JWT access token for persistent login.
    
    The token never expires by default (persistent login requirement).
    The token is stored in database for validation and revocation.
    """
    # Generate unique token data
    token_data = {
        "sub": str(user_id),
        "iat": datetime.utcnow(),
        "jti": secrets.token_hex(16),  # Unique token ID
        "type": "access"
    }
    
    # Only add expiration if specified
    expires_at = None
    if expires_delta:
        expires_at = datetime.utcnow() + expires_delta
        token_data["exp"] = expires_at
    
    # Encode JWT
    token = jwt.encode(token_data, SECRET_KEY, algorithm=ALGORITHM)
    
    # Store token in database for validation/revocation
    db_token = AuthToken(
        user_id=user_id,
        token=token,
        expires_at=expires_at,
        device_info=device_info,
        ip_address=ip_address,
        is_active=True
    )
    db.add(db_token)
    db.commit()
    
    return token


def verify_token(token: str, db: Session) -> Optional[User]:
    """
    Verify a JWT token and return the associated user.
    
    Checks:
    1. Token format and signature
    2. Token exists in database
    3. Token is active (not revoked)
    4. Token not expired (if expiration set)
    5. User exists and is active
    """
    try:
        # Decode JWT (allows expired tokens - we check manually)
        payload = jwt.decode(
            token, 
            SECRET_KEY, 
            algorithms=[ALGORITHM],
            options={"verify_exp": False}  # We check expiration manually
        )
        user_id = int(payload.get("sub"))
        
        # Check token in database
        db_token = db.query(AuthToken).filter(
            AuthToken.token == token,
            AuthToken.is_active == True
        ).first()
        
        if not db_token:
            return None
        
        # Check expiration (if set)
        if db_token.expires_at and db_token.expires_at < datetime.utcnow():
            # Mark as inactive
            db_token.is_active = False
            db.commit()
            return None
        
        # Update last used
        db_token.last_used_at = datetime.utcnow()
        db.commit()
        
        # Get user
        user = db.query(User).filter(
            User.id == user_id,
            User.is_active == True
        ).first()
        
        return user
        
    except jwt.PyJWTError:
        return None
    except Exception:
        return None


def invalidate_token(token: str, db: Session) -> bool:
    """Invalidate (revoke) a token for logout"""
    db_token = db.query(AuthToken).filter(AuthToken.token == token).first()
    if db_token:
        db_token.is_active = False
        db.commit()
        return True
    return False


def invalidate_all_user_tokens(user_id: int, db: Session) -> int:
    """Invalidate all tokens for a user (force logout everywhere)"""
    count = db.query(AuthToken).filter(
        AuthToken.user_id == user_id,
        AuthToken.is_active == True
    ).update({"is_active": False})
    db.commit()
    return count


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> User:
    """
    FastAPI dependency to get current authenticated user.
    
    Usage:
        @app.get("/protected")
        def protected_route(user: User = Depends(get_current_user)):
            return {"user": user.name}
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or expired token",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    if not credentials:
        raise credentials_exception
    
    user = verify_token(credentials.credentials, db)
    if not user:
        raise credentials_exception
    
    return user


async def get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_db)
) -> Optional[User]:
    """
    Optional authentication - returns None if not authenticated.
    
    Usage:
        @app.get("/public")
        def public_route(user: Optional[User] = Depends(get_current_user_optional)):
            if user:
                return {"message": f"Hello, {user.name}"}
            return {"message": "Hello, guest"}
    """
    if not credentials:
        return None
    
    return verify_token(credentials.credentials, db)
