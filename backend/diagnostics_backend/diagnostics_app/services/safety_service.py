import re
from typing import Optional, Dict, Any, List

class SafetyService:
    def __init__(self):
        # Critical keywords that trigger immediate emergency response
        # LIFE-THREATENING conditions that need IMMEDIATE 911/emergency response
        self.emergency_patterns = [
            # Mental Health Emergencies
            r"\bsuicid", r"\bkill myself", r"\bwant to die", r"\bend my life",
            r"\bharm myself", r"\bself.?harm",
            
            # Cardiac Emergencies
            r"\bcardiac arrest", r"\bheart attack", r"\bheart stop",
            r"\bchest pain\b", r"\bchest tightness", r"\bchest pressure",
            r"\bheart racing", r"\birregular heartbeat", r"\bpalpitation",
            
            # Respiratory Emergencies  
            r"\bcant breathe\b", r"\bcan't breathe\b", r"\bcannot breathe",
            r"\bdifficulty breathing", r"\bshortness of breath", r"\bchoking",
            r"\bcan't get air", r"\bgasping",
            
            # Neurological Emergencies
            r"\bstroke\b", r"\bseizure", r"\bconvulsion",
            r"\bslurred speech", r"\bface droop", r"\barm weakness",
            r"\bsudden confusion", r"\bsudden numbness",
            r"\bworst headache", r"\bthunderclap headache",
            r"\bloss of consciousness", r"\bpassed out", r"\bfainted",
            r"\bunresponsive",
            
            # Trauma/Bleeding Emergencies
            r"\bsevere bleeding", r"\buncontrollable bleeding",
            r"\bhead injury", r"\bhead trauma",
            r"\bsevere burn", r"\belectrocution",
            
            # Other Critical
            r"\boverdose", r"\bpoisoning", r"\ballergic reaction.*severe",
            r"\banaphyla", r"\bswelling.*throat", r"\bthroat.*closing"
        ]

    def check_safety(self, text_input: str) -> Optional[Dict[str, Any]]:
        """
        Checks input for safety flags. 
        Returns a TriageOutput-like dict if unsafe, else None.
        
        CRITICAL: This is the FIRST line of defense. If ANY emergency keyword
        is detected, we IMMEDIATELY return a critical response - no questions asked.
        """
        text_lower = text_input.lower()
        
        for pattern in self.emergency_patterns:
            if re.search(pattern, text_lower):
                return self._create_emergency_response(text_lower)
        
        return None

    def _create_emergency_response(self, symptoms: str = "") -> Dict[str, Any]:
        """Create appropriate emergency response based on detected symptoms."""
        
        # Determine the type of emergency for more specific guidance
        is_cardiac = any(term in symptoms for term in [
            "cardiac", "heart", "chest pain", "chest tight", "chest pressure"
        ])
        is_respiratory = any(term in symptoms for term in [
            "breathe", "breathing", "choking", "gasping", "air"
        ])
        is_stroke = any(term in symptoms for term in [
            "stroke", "slurred", "face droop", "arm weak", "sudden numb"
        ])
        is_mental_health = any(term in symptoms for term in [
            "suicid", "kill myself", "want to die", "harm myself"
        ])
        
        # Build specific guidance
        if is_cardiac:
            summary = "🚨 CRITICAL: POTENTIAL CARDIAC EMERGENCY DETECTED"
            immediate_actions = [
                "Call 911/112 IMMEDIATELY",
                "If available, chew aspirin (unless allergic)",
                "Sit or lie down in a comfortable position",
                "Loosen any tight clothing",
                "If you have prescribed nitroglycerin, take as directed",
                "Stay calm and wait for emergency services"
            ]
        elif is_respiratory:
            summary = "🚨 CRITICAL: BREATHING EMERGENCY DETECTED"
            immediate_actions = [
                "Call 911/112 IMMEDIATELY",
                "If choking, perform Heimlich maneuver or get help",
                "Sit upright to ease breathing",
                "Use rescue inhaler if you have asthma",
                "Stay calm, panic worsens breathing difficulty"
            ]
        elif is_stroke:
            summary = "🚨 CRITICAL: POTENTIAL STROKE - TIME IS CRITICAL"
            immediate_actions = [
                "Call 911/112 IMMEDIATELY - Every minute counts!",
                "Note the TIME symptoms started (critical for treatment)",
                "F.A.S.T.: Face drooping, Arm weakness, Speech difficulty, Time to call 911",
                "Do NOT give food/water (risk of choking)",
                "Lay person on side if vomiting"
            ]
        elif is_mental_health:
            summary = "🚨 CRISIS SUPPORT NEEDED - You are not alone"
            immediate_actions = [
                "Call emergency services (911/112) if in immediate danger",
                "National Suicide Prevention Lifeline: 988 (US)",
                "iCall (India): 9152987821",
                "Vandrevala Foundation (India): 1860-2662-345",
                "Crisis Text Line: Text HOME to 741741",
                "Stay on the line - someone cares about you"
            ]
        else:
            summary = "🚨 CRITICAL: EMERGENCY SYMPTOMS DETECTED"
            immediate_actions = [
                "Call 911/112 IMMEDIATELY",
                "Do not ignore these symptoms",
                "Stay calm and await emergency services"
            ]
        
        return {
            "summary": summary,
            "severity": "critical",
            "possible_causes": [],
            "home_care": immediate_actions,
            "prevention": [],
            "red_flags": ["THIS IS AN EMERGENCY - Do not delay seeking help"],
            "when_to_seek_care": [
                "🚨 SEEK HELP NOW - Call 911/112 immediately",
                "Go to the nearest emergency room",
                "Do NOT drive yourself - have someone else drive or call ambulance"
            ],
            "disclaimer": "This system has detected potential emergency symptoms. This is NOT a diagnosis - emergency services can provide proper evaluation."
        }
