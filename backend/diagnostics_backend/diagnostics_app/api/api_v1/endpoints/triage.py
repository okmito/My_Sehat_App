from fastapi import APIRouter, Body
from pydantic import BaseModel

router = APIRouter()

class TriageRequest(BaseModel):
    symptom_text: str

@router.get("/")
def read_root():
    return {"message": "Triage API is running"}

@router.post("/text")
def analyze_symptoms_text(request: TriageRequest = Body(...)):
    """
    Mock triage endpoint for text symptoms.
    """
    symptoms = request.symptom_text.lower()
    urgency = "low"
    advice = "Monitor your symptoms."
    
    if "pain" in symptoms or "severe" in symptoms:
        urgency = "medium"
        advice = "Consider seeing a doctor if pain persists."
    if "chest" in symptoms or "breath" in symptoms:
        urgency = "high"
        advice = "Please seek immediate medical attention."
        
    return {
        "urgency": urgency,
        "advice": advice,
        "possible_causes": ["Muscle strain", "Fatigue", "Viral infection"]
    }