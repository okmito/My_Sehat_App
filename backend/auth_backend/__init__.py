"""
Authentication Backend for MySehat Platform
============================================

Implements user authentication, preferences, and consent management
with DPDP Act 2023 compliance.
"""

from .models import (
    User, UserPreferences, UserConsent,
    UserCreate, UserLogin, UserResponse,
    PreferencesCreate, PreferencesResponse,
    ConsentCreate, ConsentResponse,
    AuthToken, TokenResponse
)
from .database import get_db, init_db, seed_database
from .auth import (
    create_access_token, verify_token,
    get_current_user, hash_password, verify_password
)
from .router import router as auth_router
from .app import app_standalone

__all__ = [
    'User', 'UserPreferences', 'UserConsent',
    'UserCreate', 'UserLogin', 'UserResponse',
    'PreferencesCreate', 'PreferencesResponse',
    'ConsentCreate', 'ConsentResponse',
    'AuthToken', 'TokenResponse',
    'get_db', 'init_db', 'seed_database',
    'create_access_token', 'verify_token',
    'get_current_user', 'hash_password', 'verify_password',
    'auth_router',
    'app_standalone'
]
