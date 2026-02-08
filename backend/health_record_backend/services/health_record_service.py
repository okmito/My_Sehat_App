"""
Health Record CRUD Service
Handles database operations with DPDP compliance
"""
from datetime import datetime, timedelta
from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_, and_

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from models.health_record import (
    HealthRecord, 
    ExtractedMedication, 
    ExtractedTestResult,
    CriticalHealthInfo,
    ConsentLog
)
from models.schemas import (
    DocumentAnalysisResponse,
    HealthRecordCreate,
    StorageType,
    SearchRequest,
    CriticalInfoBase
)
from core.config import settings


class HealthRecordService:
    """Service for health record CRUD operations"""
    
    def create_from_analysis(
        self, 
        db: Session, 
        user_id: str,
        analysis: DocumentAnalysisResponse,
        storage_type: StorageType,
        consent_given: bool,
        file_path: Optional[str] = None,
        raw_text: Optional[str] = None
    ) -> HealthRecord:
        """Create a health record from document analysis"""
        
        # Calculate auto-delete date for temporary storage
        auto_delete_date = None
        if storage_type == StorageType.TEMPORARY:
            auto_delete_date = datetime.utcnow() + timedelta(days=settings.TEMP_STORAGE_DAYS)
        
        # Parse document date
        doc_date = None
        if analysis.date:
            try:
                doc_date = datetime.strptime(analysis.date, "%Y-%m-%d")
            except ValueError:
                pass
        
        # Create health record
        health_record = HealthRecord(
            user_id=user_id,
            document_type=analysis.document_type,
            document_date=doc_date,
            doctor_name=analysis.doctor,
            hospital_name=analysis.hospital,
            patient_name=analysis.patient_name,
            diagnosis=analysis.diagnosis,
            notes=analysis.notes,
            file_path=file_path,
            raw_text=raw_text,
            confidence_score=analysis.overall_confidence,
            consent_given=consent_given,
            consent_timestamp=datetime.utcnow() if consent_given else None,
            storage_type=storage_type.value,
            auto_delete_date=auto_delete_date,
            purpose_tag=analysis.purpose_tag,
            storage_policy=analysis.storage_policy
        )
        
        db.add(health_record)
        db.flush()  # Get the ID
        
        # Add medications
        for med in analysis.medications:
            medication = ExtractedMedication(
                health_record_id=health_record.id,
                name=med.name,
                dosage=med.dosage,
                frequency=med.frequency,
                duration=med.duration,
                instructions=med.instructions,
                confidence=med.confidence
            )
            db.add(medication)
        
        # Add test results
        for test in analysis.test_results:
            test_result = ExtractedTestResult(
                health_record_id=health_record.id,
                test_name=test.test_name,
                result_value=test.result_value,
                unit=test.unit,
                reference_range=test.reference_range,
                is_abnormal=test.is_abnormal,
                confidence=test.confidence
            )
            db.add(test_result)
        
        # Add critical info
        for info in analysis.critical_info:
            critical_info = CriticalHealthInfo(
                health_record_id=health_record.id,
                user_id=user_id,
                info_type=info.info_type.value,
                value=info.value,
                severity=info.severity,
                share_in_emergency=info.share_in_emergency
            )
            db.add(critical_info)
        
        # Log consent
        if consent_given:
            consent_log = ConsentLog(
                user_id=user_id,
                health_record_id=health_record.id,
                action="consent_given",
                details=f"Storage type: {storage_type.value}"
            )
            db.add(consent_log)
        
        db.commit()
        db.refresh(health_record)
        
        return health_record
    
    def get_by_id(self, db: Session, record_id: int, user_id: str) -> Optional[HealthRecord]:
        """Get a health record by ID for a specific user"""
        return db.query(HealthRecord).filter(
            HealthRecord.id == record_id,
            HealthRecord.user_id == user_id,
            HealthRecord.is_deleted == False
        ).first()
    
    def get_user_records(
        self, 
        db: Session, 
        user_id: str,
        skip: int = 0,
        limit: int = 50
    ) -> List[HealthRecord]:
        """Get all health records for a user"""
        return db.query(HealthRecord).filter(
            HealthRecord.user_id == user_id,
            HealthRecord.is_deleted == False
        ).order_by(
            HealthRecord.document_date.desc().nullsfirst(),
            HealthRecord.upload_date.desc()
        ).offset(skip).limit(limit).all()
    
    def get_timeline(self, db: Session, user_id: str) -> List[HealthRecord]:
        """Get health records as a timeline"""
        # Include all records, using upload_date as fallback if document_date is null
        return db.query(HealthRecord).filter(
            HealthRecord.user_id == user_id,
            HealthRecord.is_deleted == False
        ).order_by(
            HealthRecord.document_date.desc().nullslast(),
            HealthRecord.upload_date.desc()
        ).all()
    
    def search_records(self, db: Session, search: SearchRequest) -> List[HealthRecord]:
        """Search health records with filters"""
        query = db.query(HealthRecord).filter(
            HealthRecord.user_id == search.user_id,
            HealthRecord.is_deleted == False
        )
        
        if search.document_type:
            query = query.filter(HealthRecord.document_type == search.document_type.value)
        
        if search.doctor_name:
            query = query.filter(HealthRecord.doctor_name.ilike(f"%{search.doctor_name}%"))
        
        if search.hospital_name:
            query = query.filter(HealthRecord.hospital_name.ilike(f"%{search.hospital_name}%"))
        
        if search.date_from:
            query = query.filter(HealthRecord.document_date >= search.date_from)
        
        if search.date_to:
            query = query.filter(HealthRecord.document_date <= search.date_to)
        
        if search.query:
            query = query.filter(
                or_(
                    HealthRecord.diagnosis.ilike(f"%{search.query}%"),
                    HealthRecord.notes.ilike(f"%{search.query}%"),
                    HealthRecord.doctor_name.ilike(f"%{search.query}%"),
                    HealthRecord.hospital_name.ilike(f"%{search.query}%")
                )
            )
        
        if search.medicine_name:
            # Join with medications table
            query = query.join(ExtractedMedication).filter(
                ExtractedMedication.name.ilike(f"%{search.medicine_name}%")
            )
        
        return query.order_by(HealthRecord.document_date.desc()).all()
    
    def verify_record(
        self, 
        db: Session, 
        record_id: int, 
        user_id: str,
        verified_data: dict
    ) -> Optional[HealthRecord]:
        """Mark a record as verified after user review"""
        record = self.get_by_id(db, record_id, user_id)
        if not record:
            return None
        
        # Update fields from verified data
        for key, value in verified_data.items():
            if hasattr(record, key) and value is not None:
                setattr(record, key, value)
        
        record.is_verified = True
        record.verified_at = datetime.utcnow()
        
        db.commit()
        db.refresh(record)
        
        return record
    
    def delete_record(self, db: Session, record_id: int, user_id: str) -> bool:
        """Soft delete a health record"""
        record = self.get_by_id(db, record_id, user_id)
        if not record:
            return False
        
        record.is_deleted = True
        record.deleted_at = datetime.utcnow()
        
        # Log deletion
        consent_log = ConsentLog(
            user_id=user_id,
            health_record_id=record_id,
            action="data_deleted",
            details="User requested deletion"
        )
        db.add(consent_log)
        
        db.commit()
        return True
    
    def revoke_consent(self, db: Session, record_id: int, user_id: str) -> bool:
        """Revoke consent and delete data"""
        record = self.get_by_id(db, record_id, user_id)
        if not record:
            return False
        
        record.consent_given = False
        record.is_deleted = True
        record.deleted_at = datetime.utcnow()
        
        # Log consent revocation
        consent_log = ConsentLog(
            user_id=user_id,
            health_record_id=record_id,
            action="consent_revoked",
            details="User revoked consent - data deleted"
        )
        db.add(consent_log)
        
        db.commit()
        return True
    
    def get_emergency_data(self, db: Session, user_id: str) -> dict:
        """Get only critical health info for emergency access"""
        critical_info = db.query(CriticalHealthInfo).filter(
            CriticalHealthInfo.user_id == user_id,
            CriticalHealthInfo.share_in_emergency == True
        ).all()
        
        blood_group = None
        allergies = []
        chronic_conditions = []
        
        for info in critical_info:
            if info.info_type == "blood_group":
                blood_group = info.value
            elif info.info_type == "allergy":
                allergies.append({
                    "allergen": info.value,
                    "severity": info.severity
                })
            elif info.info_type == "chronic_condition":
                chronic_conditions.append(info.value)
        
        return {
            "blood_group": blood_group,
            "allergies": allergies,
            "chronic_conditions": chronic_conditions,
            "disclaimer": "Emergency responders see only life-critical information, nothing else."
        }
    
    def set_emergency_accessible(
        self, 
        db: Session, 
        record_id: int, 
        user_id: str,
        accessible: bool
    ) -> bool:
        """Set whether a record's critical info is accessible in emergencies"""
        record = self.get_by_id(db, record_id, user_id)
        if not record:
            return False
        
        record.is_emergency_accessible = accessible
        db.commit()
        return True
    
    def cleanup_expired_records(self, db: Session) -> int:
        """Delete records that have passed their auto-delete date"""
        now = datetime.utcnow()
        expired = db.query(HealthRecord).filter(
            HealthRecord.storage_type == "temporary",
            HealthRecord.auto_delete_date <= now,
            HealthRecord.is_deleted == False
        ).all()
        
        count = 0
        for record in expired:
            record.is_deleted = True
            record.deleted_at = now
            
            consent_log = ConsentLog(
                user_id=record.user_id,
                health_record_id=record.id,
                action="data_deleted",
                details="Auto-deleted after temporary storage period"
            )
            db.add(consent_log)
            count += 1
        
        db.commit()
        return count


# Singleton instance
health_record_service = HealthRecordService()
