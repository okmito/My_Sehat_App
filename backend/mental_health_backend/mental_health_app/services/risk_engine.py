from typing import List, Tuple
import re
import logging

# Configure logger
logger = logging.getLogger("risk_engine")
logger.setLevel(logging.INFO)
if not logger.handlers:
    sh = logging.StreamHandler()
    sh.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    logger.addHandler(sh)

# Simple keyword lists for scoring (extensible)
SELF_HARM_KEYWORDS = [
    "kill myself", "suicide", "end it all", "die", "hurt myself", 
    "cutting", "overdose", "jump", "hang myself", "no way out"
]

HIGH_RISK_KEYWORDS = [
    "hopeless", "worthless", "trapped", "unbearable", "desperate", 
    "give up", "burden", "goodbye"
]

# Robust Regex Patterns for Intent Detection
SELF_HARM_PATTERNS = [
    r"(kill|killing|killed)\s+(myself|me)",  # killing myself
    r"(end|ending)\s+(my life|it all)",      # ending my life
    r"(want|wanna|wish)\s+to\s+(die|kill myself|disappear)", # want to die
    r"suicid(e|al)",                         # suicide/suicidal
    r"better\s+off\s+dead",                  # better off dead
    r"please\s+let\s+me\s+die",              # please let me die
    r"take\s+my\s+(own\s+)?life"             # take my life
]

def detect_self_harm_intent(text: str) -> Tuple[bool, str]:
    """
    Returns (True, matched_pattern) if high-risk intent is detected via regex.
    """
    text_norm = text.lower().strip()
    
    for pattern in SELF_HARM_PATTERNS:
        match = re.search(pattern, text_norm)
        if match:
            logger.warning(f"Self-harm intent detected via regex: '{pattern}' in text: '{text}'")
            return True, pattern
            
    return False, ""

def calculate_risk_score(text: str) -> Tuple[int, List[str]]:
    """
    Returns (score, reasons)
    """
    text_lower = text.lower()
    score = 0
    reasons = []

    # 1. Check Deterministic Intent (Highest Priority)
    intent_found, pattern = detect_self_harm_intent(text)
    if intent_found:
        score += 20  # Massive boost to ensure HIGH/CRITICAL
        reasons.append(f"Detected self-harm intent (pattern: {pattern})")

    # 2. Check self-harm keywords (High impact)
    for kw in SELF_HARM_KEYWORDS:
        if kw in text_lower:
            score += 5
            reasons.append(f"Detected self-harm keyword: '{kw}'")

    # 3. Check general high risk keywords
    for kw in HIGH_RISK_KEYWORDS:
        if kw in text_lower:
            score += 2
            reasons.append(f"Detected high-risk keyword: '{kw}'")

    return score, list(set(reasons))

def determinize_risk_level(llm_risk: str, keyword_score: int, self_harm_detected_llm: bool) -> str:
    """
    Combine LLM assessment with deterministic keyword scoring.
    Enforces safety rules:
    - If keyword_score >= 20 (Intent Detected) -> HIGH or CRITICAL
    - If self_harm_detected_llm -> HIGH or CRITICAL
    """
    # Normalize inputs
    llm_risk = llm_risk.lower().strip()
    
    # Critical/High Safety Override
    # If regex intent found (score >= 20) OR LLM flagged self-harm OR existing keyword logic matches
    if keyword_score >= 20 or self_harm_detected_llm:
        if llm_risk == "critical":
            return "critical"
        return "high"
        
    if keyword_score >= 5:
        if llm_risk == "critical":
            return "critical"
        return "high"
    
    # Moderate overrides
    if keyword_score >= 2:
        if llm_risk in ["none", "low"]:
            return "medium"
    
    return llm_risk

def get_actions(risk_level: str) -> List[str]:
    """
    Return list of proposed UI actions based on risk.
    """
    risk_level = risk_level.lower()
    
    if risk_level in ["high", "critical"]:
        return ["SHOW_SOS", "SHOW_HELPLINE", "SUGGEST_TRUSTED_CONTACT"]
    elif risk_level == "medium":
        return ["SUGGEST_TRUSTED_CONTACT"]
    else:
        return ["NONE"]
