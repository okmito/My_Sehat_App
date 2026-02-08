"""
Database Management for Authentication Backend
===============================================

Handles database initialization, session management, and seeding.
"""

import os
import json
from datetime import datetime
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from typing import Generator

from .models import Base, User, UserPreferences, UserConsent, AuthToken

# Database path
DB_PATH = os.path.join(os.path.dirname(__file__), "..", "auth.db")
DATABASE_URL = f"sqlite:///{DB_PATH}"

# Create engine and session
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    """Dependency for getting database session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables"""
    Base.metadata.create_all(bind=engine)
    print(f"✅ Auth database initialized at {DB_PATH}")


def seed_database():
    """
    Seed database with required demo users.
    
    Creates exactly 4 users as specified:
    - Mitesh Sai: 9999999999
    - Aakanksha: 8888888888
    - Srinidhi: 7777777777
    - Rupak: 6666666666
    """
    db = SessionLocal()
    
    try:
        # Check if users already exist
        existing = db.query(User).filter(User.phone_number.in_([
            "9999999999", "8888888888", "7777777777", "6666666666"
        ])).count()
        
        if existing >= 4:
            print("✅ Seed users already exist, skipping seeding")
            return
        
        # Define seed users
        seed_users = [
            {
                "name": "Mitesh Sai",
                "phone_number": "9999999999",
                "age": 28,
                "gender": "Male",
                "blood_group": "O+",
                "allergies": json.dumps(["Peanuts"]),
                "conditions": json.dumps(["Diabetes"]),
                "emergency_contact": "Sai Family",
                "emergency_phone": "9876543210",
                "preferences": {
                    "language": "en",
                    "emergency_enabled": True,
                    "medicine_reminders": True,
                    "notification_enabled": True,
                    "dark_mode": False
                },
                "consents": [
                    {"data_category": "emergency", "purpose": "emergency_sharing", "granted": True},
                    {"data_category": "health_records", "purpose": "health_record_storage", "granted": True},
                    {"data_category": "ai_symptoms", "purpose": "ai_symptom_checker", "granted": True},
                    {"data_category": "mental_health", "purpose": "mental_health_processing", "granted": False},
                    {"data_category": "medications", "purpose": "medicine_reminders", "granted": True},
                ]
            },
            {
                "name": "Aakanksha",
                "phone_number": "8888888888",
                "age": 25,
                "gender": "Female",
                "blood_group": "A+",
                "allergies": json.dumps([]),
                "conditions": json.dumps(["Asthma"]),
                "emergency_contact": "Parents",
                "emergency_phone": "8765432109",
                "preferences": {
                    "language": "hi",
                    "emergency_enabled": True,
                    "medicine_reminders": True,
                    "notification_enabled": True,
                    "dark_mode": True
                },
                "consents": [
                    {"data_category": "emergency", "purpose": "emergency_sharing", "granted": True},
                    {"data_category": "health_records", "purpose": "health_record_storage", "granted": True},
                    {"data_category": "ai_symptoms", "purpose": "ai_symptom_checker", "granted": True},
                    {"data_category": "mental_health", "purpose": "mental_health_processing", "granted": True},
                    {"data_category": "medications", "purpose": "medicine_reminders", "granted": True},
                ]
            },
            {
                "name": "Srinidhi",
                "phone_number": "7777777777",
                "age": 30,
                "gender": "Female",
                "blood_group": "B+",
                "allergies": json.dumps(["Penicillin"]),
                "conditions": json.dumps([]),
                "emergency_contact": "Spouse",
                "emergency_phone": "7654321098",
                "preferences": {
                    "language": "en",
                    "emergency_enabled": True,
                    "medicine_reminders": False,
                    "notification_enabled": True,
                    "dark_mode": False
                },
                "consents": [
                    {"data_category": "emergency", "purpose": "emergency_sharing", "granted": True},
                    {"data_category": "health_records", "purpose": "health_record_storage", "granted": True},
                    {"data_category": "ai_symptoms", "purpose": "ai_symptom_checker", "granted": True},
                    {"data_category": "mental_health", "purpose": "mental_health_processing", "granted": False},
                    {"data_category": "medications", "purpose": "medicine_reminders", "granted": False},
                ]
            },
            {
                "name": "Rupak",
                "phone_number": "6666666666",
                "age": 35,
                "gender": "Male",
                "blood_group": "AB+",
                "allergies": json.dumps(["Sulfa"]),
                "conditions": json.dumps(["Hypertension", "High Cholesterol"]),
                "emergency_contact": "Brother",
                "emergency_phone": "6543210987",
                "preferences": {
                    "language": "en",
                    "emergency_enabled": True,
                    "medicine_reminders": True,
                    "notification_enabled": False,
                    "dark_mode": True
                },
                "consents": [
                    {"data_category": "emergency", "purpose": "emergency_sharing", "granted": True},
                    {"data_category": "health_records", "purpose": "health_record_storage", "granted": True},
                    {"data_category": "ai_symptoms", "purpose": "ai_symptom_checker", "granted": True},
                    {"data_category": "mental_health", "purpose": "mental_health_processing", "granted": True},
                    {"data_category": "medications", "purpose": "medicine_reminders", "granted": True},
                ]
            }
        ]
        
        for user_data in seed_users:
            # Check if this specific user exists
            existing_user = db.query(User).filter(
                User.phone_number == user_data["phone_number"]
            ).first()
            
            if existing_user:
                print(f"⏭️  User {user_data['name']} already exists, skipping")
                continue
            
            # Create user
            user = User(
                name=user_data["name"],
                phone_number=user_data["phone_number"],
                age=user_data["age"],
                gender=user_data["gender"],
                blood_group=user_data["blood_group"],
                allergies=user_data["allergies"],
                conditions=user_data["conditions"],
                emergency_contact=user_data["emergency_contact"],
                emergency_phone=user_data["emergency_phone"],
            )
            db.add(user)
            db.flush()  # Get user ID
            
            # Create preferences
            prefs = UserPreferences(
                user_id=user.id,
                **user_data["preferences"]
            )
            db.add(prefs)
            
            # Create consents
            for consent_data in user_data["consents"]:
                consent = UserConsent(
                    user_id=user.id,
                    data_category=consent_data["data_category"],
                    purpose=consent_data["purpose"],
                    granted=consent_data["granted"],
                    consent_text=f"User consented to {consent_data['purpose']} for {consent_data['data_category']} data"
                )
                db.add(consent)
            
            print(f"✅ Created seed user: {user_data['name']} ({user_data['phone_number']})")
        
        db.commit()
        print("\n🌱 Database seeding completed!")
        
    except Exception as e:
        db.rollback()
        print(f"❌ Error seeding database: {e}")
        raise
    finally:
        db.close()


# Initialize on import
if __name__ == "__main__":
    init_db()
    seed_database()
