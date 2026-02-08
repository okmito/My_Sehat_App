import sys
from pathlib import Path
from typing import Dict, Any, List

# Add parent directory to path for relative imports
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from models.schemas import TriageOutputSchema, Question

# --- QUESTION TEMPLATES ---
SYSTEMIC_QUESTIONS = [
    Question(
        id="q_systemic_1",
        text="How high is your fever and how long has it lasted?",
        options=["Low grade (<38C), <2 days", "High grade (>38C), <2 days", "Any fever > 3 days"],
        allow_custom=True
    ),
    Question(
        id="q_systemic_2",
        text="Are you experiencing severe dehydration (dry mouth, no urine)?",
        options=["Yes", "No"],
        allow_custom=False
    )
]

GI_QUESTIONS = [
    Question(
        id="q_gi_1",
        text="Do you have any nausea, vomiting, or diarrhea?",
        options=["Yes, nausea only", "Vomiting", "Diarrhea", "None"],
        allow_custom=True
    )
]

HEADACHE_QUESTIONS = [
    Question(
        id="q_headache_1",
        text="Is the headache throbbing, squeezing, or sharp?",
        options=["Throbbing", "Squeezing (band-like)", "Sharp/Stabbing"],
        allow_custom=True
    )
]

GENERAL_QUESTIONS = [
    Question(
        id="q_general_1",
        text="Can you describe your symptoms in more detail?",
        options=["pain", "weakness", "discomfort"],
        allow_custom=True
    )
]

WOUND_QUESTIONS = [
    Question(
        id="q_wound_1",
        text="Is the wound deep or showing signs of infection (pus, warmth)?",
        options=["Superficial, clean", "Deep, bleeding controlled", "Signs of infection"],
        allow_custom=True
    ),
    Question(
        id="q_wound_2",
        text="Is the bleeding uncontrollable?",
        options=["Yes", "No - stopped with pressure"],
        allow_custom=False
    )
]

SKIN_QUESTIONS = [
    Question(
        id="q_skin_1",
        text="Is the rash itchy or painful?",
        options=["Itchy", "Painful", "Both", "Neither"],
        allow_custom=True
    ),
    Question(
        id="q_skin_2",
        text="Is the rash spreading rapidly?",
        options=["Yes", "No", "Stable"],
        allow_custom=False
    )
]

MUSCULOSKELETAL_QUESTIONS = [
    Question(
        id="q_musculo_1",
        text="How did the pain start and how long have you had it?",
        options=["Sudden injury/trauma", "Gradual onset, < 1 week", "Chronic, > 1 week"],
        allow_custom=True
    ),
    Question(
        id="q_musculo_2",
        text="Is there any swelling, redness, or limited movement?",
        options=["Yes, swelling", "Yes, redness/warmth", "Limited movement", "None of these"],
        allow_custom=True
    )
]

CONFIRMATION_QUESTION = Question(
    id="q_continue_1",
    text="Do you want to continue (upload another image or describe symptoms) to improve accuracy?",
    options=["Yes, upload another image", "Yes, add symptoms in text", "No, finalize now"],
    allow_custom=False
)

class ReasoningService:
    def __init__(self):
        pass

    async def generate_question(self, session_data: Dict[str, Any]) -> Question:
        """
        Returns a question based on STRICT domain separation and SYMPTOM CATEGORIZATION.
        Rules:
        - input_mode="text" -> Route to specific systemic category (Headache, GI, Fever, General)
        - input_mode="image" -> WOUND vs SKIN based on observations
        """
        input_mode = session_data.get("input_mode", "mixed")
        observations = session_data.get("observations", {}).get("observations", [])
        
        # Context Variables
        severity = session_data.get("severity", "").lower() if session_data.get("severity") else ""
        duration = session_data.get("duration", "").lower() if session_data.get("duration") else ""
        symptoms = session_data.get("symptoms", "").lower()

        # FIX 3: TEXT TRIAGE SAFETY RULE
        if input_mode == "text":
            # 1. PARSE & CATEGORIZE
            # Categories: infection_risk, headache, mild_gi, vomiting, general
            
            # Keywords
            infection_kws = ["fever", "chills", "shivering", "hot"]
            headache_kws = ["headache", "head pain", "migraine"]
            gi_kws = ["uneasy", "stomach", "nausea", "indigestion", "bloating", "gas"]
            vomit_kws = ["vomit", "throwing up", "puke"]
            musculo_kws = ["pain", "ache", "sore", "hurt", "swelling", "stiff", "sprain", "strain",
                          "thumb", "finger", "hand", "wrist", "arm", "elbow", "shoulder",
                          "knee", "ankle", "foot", "toe", "leg", "hip", "back", "neck", "joint"]
            
            has_infection = any(k in symptoms for k in infection_kws)
            has_headache = any(k in symptoms for k in headache_kws)
            has_gi = any(k in symptoms for k in gi_kws)
            has_vomit = any(k in symptoms for k in vomit_kws)
            has_musculo = any(k in symptoms for k in musculo_kws)
            
            # Duration logic for vomiting (>= 2 days -> Fever/Systemic check)
            # Stub: check for "2 days", "3 days", "week"
            is_long_duration = any(t in duration for t in ["2 day", "3 day", "4 day", "5 day", "week"])
            
            # 2. SELECT QUESTION
            
            # Priority A: Infection/Fever keywords -> FORCE FEVER Q
            if has_infection:
                return SYSTEMIC_QUESTIONS[0]
            
            # Priority B: Vomiting + Long Duration -> FEVER Q (Risk of systemic issue)
            if has_vomit and is_long_duration:
                return SYSTEMIC_QUESTIONS[0]
                
            # Priority C: Headache -> HEADACHE Q
            if has_headache:
                return HEADACHE_QUESTIONS[0]
            
            # Priority D: Mild GI / Vomiting (short term) -> GI Q
            if has_gi or has_vomit:
                return GI_QUESTIONS[0]
            
            # Priority E: Musculoskeletal (pain, joint, body parts) -> MUSCULO Q
            if has_musculo:
                return MUSCULOSKELETAL_QUESTIONS[0]
                
            # Priority F: General -> GENERAL Q (Default)
            # Fever question must NOT be default
            return GENERAL_QUESTIONS[0]

        if input_mode == "image" or input_mode == "mixed":
            if "open wound" in observations or "bleeding" in observations:
                return WOUND_QUESTIONS[0]
            elif "redness" in observations or "rash" in observations:
                return SKIN_QUESTIONS[0]
            
            # If mixed (image + text) and no specific image observations, check text symptoms
            if input_mode == "mixed" and symptoms:
                 # Re-use text logic for mixed fallback
                 infection_kws = ["fever", "chills", "shivering", "hot"]
                 headache_kws = ["headache", "head pain", "migraine"]
                 gi_kws = ["uneasy", "stomach", "nausea", "indigestion", "bloating", "gas"]
                 vomit_kws = ["vomit", "throwing up", "puke"]
                 
                 if any(k in symptoms for k in infection_kws): return SYSTEMIC_QUESTIONS[0]
                 if any(k in symptoms for k in headache_kws): return HEADACHE_QUESTIONS[0]
                 if any(k in symptoms for k in gi_kws) or any(k in symptoms for k in vomit_kws): return GI_QUESTIONS[0]
        
        # Default Fallback (should be Systemic if unknown)
        return SYSTEMIC_QUESTIONS[0]

    async def analyze_symptoms(self, session_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        Returns a final triage result based on STRICT DOMAIN.
        Analyzes ALL conversation context including follow-up answers.
        """
        input_mode = session_data.get("input_mode", "mixed")
        observations = session_data.get("observations", {}).get("observations", [])
        
        symptoms = session_data.get("symptoms", "").lower()
        
        # 1. TEXT MODE -> Categorize based on symptoms
        if input_mode == "text":
            # Define keyword groups - ORDER MATTERS for priority
            headache_kws = ["headache", "head pain", "migraine", "head ache"]
            gi_kws = ["stomach", "nausea", "vomit", "diarrhea", "bloating", "stomach pain", 
                      "abdominal", "belly", "gastric", "indigestion", "acid reflux", "heartburn"]
            infection_kws = ["fever", "chills", "cold", "flu", "temperature"]
            respiratory_kws = ["cough", "breathing", "breath", "chest pain", "wheezing", "congestion",
                              "runny nose", "sore throat", "throat pain"]
            skin_kws = ["rash", "itchy", "itching", "hives", "skin", "bump", "acne", "pimple"]
            
            # Autonomic symptoms (sweating, shivering WITHOUT fever)
            autonomic_kws = ["sweating", "sweat", "shivering", "shiver", "trembling", "tremble", 
                            "shaking", "clammy", "cold sweat"]
            
            # Musculoskeletal - only body parts + pain indicators (NOT generic "pain" alone)
            body_parts = ["thumb", "finger", "hand", "wrist", "arm", "elbow", "shoulder",
                          "knee", "ankle", "foot", "toe", "leg", "hip", "back", "neck", 
                          "joint", "muscle", "spine"]
            musculo_indicators = ["sprain", "strain", "swelling", "stiff", "ache", "sore", "injury"]
            
            # Check for specific body part mentioned with pain context
            has_body_part = any(part in symptoms for part in body_parts)
            has_musculo_indicator = any(ind in symptoms for ind in musculo_indicators)
            
            # Check if user explicitly denied having fever
            no_fever_phrases = ["no fever", "don't have a fever", "don't have fever", 
                               "not have fever", "no temperature", "haven't got fever",
                               "i don't have a fever", "i dont have fever"]
            has_no_fever = any(phrase in symptoms for phrase in no_fever_phrases)
            
            # Check for autonomic symptoms (sweating/shivering)
            has_autonomic = any(k in symptoms for k in autonomic_kws)
            
            # SPECIAL CASE: Sweating/shivering + explicitly no fever -> autonomic response
            if has_autonomic and has_no_fever:
                return self._get_autonomic_response()
            
            # SPECIAL CASE: Sweating/shivering + no mention of fever keywords -> autonomic response
            has_fever_kw = any(k in symptoms for k in infection_kws)
            if has_autonomic and not has_fever_kw:
                return self._get_autonomic_response()
            
            # Priority order: specific conditions first, musculoskeletal only if body part mentioned
            if any(k in symptoms for k in headache_kws):
                return self._get_headache_response()
            elif any(k in symptoms for k in infection_kws) and not has_no_fever:
                return self._get_systemic_response()
            elif any(k in symptoms for k in respiratory_kws):
                return self._get_respiratory_response()
            elif any(k in symptoms for k in gi_kws):
                return self._get_gi_response()
            elif any(k in symptoms for k in skin_kws):
                return self._get_skin_response()
            elif has_body_part or has_musculo_indicator:
                return self._get_musculoskeletal_response(symptoms)
            else:
                # Default general response with AI-style analysis
                return self._get_general_response(symptoms)

        # 2. IMAGE/MIXED -> Check Observations
        if "open wound" in observations or "bleeding" in observations:
            return self._get_wound_response()
        
        elif "redness" in observations or "rash" in observations:
            return self._get_skin_response()

        # Default
        return self._get_systemic_response()
    
    # --- Response Helpers ---
    def _get_systemic_response(self):
        return {
            "summary": "Symptoms consistent with a viral illness or systemic infection.",
            "severity": "medium",
            "possible_causes": [
                { "name": "Viral Influenza", "confidence": 0.78 },
                { "name": "Common Cold", "confidence": 0.65 }
            ],
            "home_care": ["Rest and hydration", "Over-the-counter antipyretics"],
            "prevention": ["Wash hands frequently"],
            "red_flags": ["Stiff neck", "Confusion", "Difficulty breathing"],
            "when_to_seek_care": ["If fever persists > 3 days", "If unable to keep fluids down"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_wound_response(self):
        return {
            "summary": "Observation of an open wound.",
            "severity": "medium",
            "possible_causes": [
                { "name": "Laceration", "confidence": 0.85 },
                { "name": "Abrasion", "confidence": 0.80 }
            ],
            "home_care": ["Clean with water", "Apply antibiotic ointment", "Cover with sterile bandage"],
            "prevention": ["Keep environment safe"],
            "red_flags": ["Uncontrollable bleeding", "Signs of infection (pus, red streaks)"],
            "when_to_seek_care": ["If wound is deep (needs stitches)", "If bleeding doesn't stop"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_skin_response(self):
        return {
            "summary": "Symptoms suggest a localized skin reaction.",
            "severity": "low",
            "possible_causes": [
                { "name": "Contact Dermatitis", "confidence": 0.75 },
                { "name": "Insect Bite", "confidence": 0.60 }
            ],
            "home_care": ["Keep clean and dry", "Apply cold compress"],
            "prevention": ["Avoid potential allergens"],
            "red_flags": ["Rapidly spreading redness", "High fever"],
            "when_to_seek_care": ["If symptoms worsen after 24 hours"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_musculoskeletal_response(self, symptoms: str):
        # Determine specific body part from symptoms
        body_parts = {
            "thumb": "thumb", "finger": "finger", "hand": "hand", "wrist": "wrist",
            "arm": "arm", "elbow": "elbow", "shoulder": "shoulder",
            "knee": "knee", "ankle": "ankle", "foot": "foot", "toe": "toe",
            "leg": "leg", "hip": "hip", "back": "back", "neck": "neck", "joint": "joint"
        }
        affected_part = "the affected area"
        for part, name in body_parts.items():
            if part in symptoms:
                affected_part = name
                break
        
        return {
            "summary": f"Symptoms suggest a musculoskeletal issue affecting {affected_part}.",
            "severity": "low",
            "possible_causes": [
                { "name": "Strain or Overuse Injury", "confidence": 0.75 },
                { "name": "Minor Sprain", "confidence": 0.65 },
                { "name": "Repetitive Stress Injury", "confidence": 0.55 },
                { "name": "Joint Inflammation", "confidence": 0.45 }
            ],
            "home_care": [
                "Rest the affected area and avoid activities that worsen pain",
                "Apply ice for 15-20 minutes several times a day",
                "Use over-the-counter pain relievers (ibuprofen, acetaminophen)",
                "Gentle stretching once pain subsides"
            ],
            "prevention": [
                "Take regular breaks during repetitive activities",
                "Use proper ergonomics",
                "Warm up before physical activities"
            ],
            "red_flags": [
                "Severe swelling or deformity",
                "Inability to move the affected area",
                "Numbness or tingling",
                "Pain that worsens despite rest"
            ],
            "when_to_seek_care": [
                "If pain persists for more than a week",
                "If swelling does not improve with ice and rest",
                "If you cannot use the affected body part normally"
            ],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_headache_response(self):
        return {
            "summary": "Symptoms suggest a tension or stress-related headache.",
            "severity": "low",
            "possible_causes": [
                { "name": "Tension Headache", "confidence": 0.80 },
                { "name": "Dehydration", "confidence": 0.60 },
                { "name": "Eye Strain", "confidence": 0.50 }
            ],
            "home_care": [
                "Rest in a quiet, dark room",
                "Stay hydrated",
                "Over-the-counter pain relievers",
                "Apply cold or warm compress to forehead"
            ],
            "prevention": ["Manage stress", "Get adequate sleep", "Limit screen time"],
            "red_flags": ["Sudden severe headache", "Headache with fever and stiff neck", "Vision changes"],
            "when_to_seek_care": ["If headache is the worst of your life", "If accompanied by confusion"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_gi_response(self):
        return {
            "summary": "Symptoms suggest a gastrointestinal issue.",
            "severity": "low",
            "possible_causes": [
                { "name": "Indigestion", "confidence": 0.70 },
                { "name": "Gastritis", "confidence": 0.55 },
                { "name": "Food Intolerance", "confidence": 0.50 }
            ],
            "home_care": [
                "Eat bland foods",
                "Stay hydrated with clear fluids",
                "Avoid spicy, fatty, or acidic foods",
                "Rest and avoid strenuous activity"
            ],
            "prevention": ["Eat smaller meals", "Avoid trigger foods", "Don't lie down right after eating"],
            "red_flags": ["Severe abdominal pain", "Blood in vomit or stool", "High fever"],
            "when_to_seek_care": ["If symptoms persist more than 2 days", "If unable to keep fluids down"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_respiratory_response(self):
        return {
            "summary": "Symptoms suggest a respiratory issue such as a common cold or upper respiratory infection.",
            "severity": "low",
            "possible_causes": [
                { "name": "Common Cold", "confidence": 0.75 },
                { "name": "Upper Respiratory Infection", "confidence": 0.70 },
                { "name": "Allergies", "confidence": 0.55 },
                { "name": "Bronchitis", "confidence": 0.40 }
            ],
            "home_care": [
                "Rest and get plenty of sleep",
                "Stay hydrated with warm fluids (tea, soup)",
                "Use honey for sore throat (if over 1 year old)",
                "Use saline nasal spray for congestion",
                "Take over-the-counter decongestants if needed"
            ],
            "prevention": ["Wash hands frequently", "Avoid close contact with sick people", "Get adequate sleep"],
            "red_flags": ["Difficulty breathing", "Chest pain", "High fever (>39°C/102°F)", "Symptoms lasting >10 days"],
            "when_to_seek_care": ["If breathing becomes difficult", "If cough produces blood", "If fever persists >3 days"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_autonomic_response(self):
        """Response for sweating, shivering, trembling WITHOUT fever (autonomic symptoms)."""
        return {
            "summary": "Symptoms suggest an autonomic nervous system response, possibly related to stress, anxiety, blood sugar changes, or temperature regulation.",
            "severity": "low",
            "possible_causes": [
                { "name": "Anxiety or Panic Response", "confidence": 0.75 },
                { "name": "Low Blood Sugar (Hypoglycemia)", "confidence": 0.65 },
                { "name": "Stress Response", "confidence": 0.60 },
                { "name": "Caffeine or Stimulant Effect", "confidence": 0.45 },
                { "name": "Cold Exposure", "confidence": 0.40 }
            ],
            "home_care": [
                "Eat something with sugar if you haven't eaten recently",
                "Practice deep breathing exercises",
                "Move to a comfortable temperature environment",
                "Sit or lie down if feeling faint",
                "Drink water and stay hydrated"
            ],
            "prevention": [
                "Eat regular meals to maintain blood sugar",
                "Practice stress management techniques",
                "Limit caffeine intake",
                "Get adequate sleep"
            ],
            "red_flags": [
                "Chest pain or pressure",
                "Difficulty breathing",
                "Confusion or altered consciousness",
                "Symptoms not improving after eating"
            ],
            "when_to_seek_care": [
                "If symptoms are frequent or recurring",
                "If accompanied by fainting or near-fainting",
                "If you have diabetes and suspect low blood sugar"
            ],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }

    def _get_general_response(self, symptoms: str):
        return {
            "summary": f"General health concern noted. Based on your symptoms: {symptoms[:100]}...",
            "severity": "low",
            "possible_causes": [
                { "name": "General Discomfort", "confidence": 0.60 },
                { "name": "Minor Health Issue", "confidence": 0.50 }
            ],
            "home_care": [
                "Get adequate rest",
                "Stay hydrated",
                "Monitor symptoms for changes"
            ],
            "prevention": ["Maintain healthy lifestyle", "Regular exercise", "Balanced diet"],
            "red_flags": ["Symptoms worsening rapidly", "New severe symptoms appearing"],
            "when_to_seek_care": ["If symptoms persist or worsen", "If you develop new concerns"],
            "disclaimer": "This is not a medical diagnosis. Consult a professional."
        }
