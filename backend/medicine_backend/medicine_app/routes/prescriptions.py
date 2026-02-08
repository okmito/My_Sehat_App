from fastapi import APIRouter, Depends, HTTPException, Header, UploadFile, File
from sqlalchemy.orm import Session
from typing import List
import shutil
import os
import uuid

from medicine_backend.medicine_app.core.db import get_db
from medicine_backend.medicine_app.core.config import settings
from medicine_backend.medicine_app.models.prescription import Prescription
from medicine_backend.medicine_app.schemas.prescription import Prescription as PrescriptionSchema, PrescriptionConfirm
from medicine_backend.medicine_app.services.prescription_service import confirm_prescription

router = APIRouter(prefix="/prescriptions", tags=["Prescriptions"])

def get_user_id(x_user_id: str = Header(...)):
    if not x_user_id:
        raise HTTPException(status_code=400, detail="X-User-Id header missing")
    return x_user_id

@router.post("/upload", response_model=PrescriptionSchema)
def upload_prescription(
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    # Save file
    file_ext = file.filename.split('.')[-1]
    filename = f"{uuid.uuid4()}.{file_ext}"
    file_path = os.path.join(settings.UPLOAD_DIR, filename)
    
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    db_prescription = Prescription(
        user_id=user_id,
        file_path=file_path,
        extraction_status="UPLOADED"
    )
    db.add(db_prescription)
    db.commit()
    db.refresh(db_prescription)
    return db_prescription

@router.get("/", response_model=List[PrescriptionSchema])
def get_prescriptions(
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    return db.query(Prescription).filter(Prescription.user_id == user_id).all()

@router.post("/{id}/confirm")
def confirm_prescription_endpoint(
    id: int,
    data: PrescriptionConfirm,
    db: Session = Depends(get_db),
    user_id: str = Depends(get_user_id)
):
    # Validate prescription exists
    prescription = db.query(Prescription).filter(
        Prescription.id == id,
        Prescription.user_id == user_id
    ).first()
    
    if not prescription:
        raise HTTPException(status_code=404, detail="Prescription not found")
        
    created_meds = confirm_prescription(db, id, data.medications, user_id)
    
    return {"status": "success", "medications_created": len(created_meds)}
