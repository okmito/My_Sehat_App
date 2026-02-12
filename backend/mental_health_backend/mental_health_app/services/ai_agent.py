
"""
Mental Health AI Agent Service
==============================

Provides LLM-based analysis for:
- Chat responses
- Risk assessment refiner
- Daily summary generation
"""

import asyncio
import random

# Fallback responses for safety or when LLM fails
FALLBACK_RESPONSES = [
    "I'm here to listen. Tell me more.",
    "That sounds tough. How are you coping?",
    "I understand. What else is on your mind?",
    "I am here for you."
]

async def analyze_message_llm(message: str, history: list) -> dict:
    """
    Simulate LLM analysis of a user message.
    In production, this would call OpenAI/Gemini/Llama API.
    """
    # Simulate processing delay
    await asyncio.sleep(0.5)
    
    # Simple keyword-based mock analysis
    message_lower = message.lower()
    
    risk_level = "low"
    self_harm = False
    
    if "kill" in message_lower or "suicide" in message_lower or "die" in message_lower:
        risk_level = "critical"
        self_harm = True
    elif "hurt" in message_lower or "pain" in message_lower or "sad" in message_lower:
        risk_level = "medium"
    
    # Mock response generation
    reply = "I understand you're feeling this way. Can you tell me more?"
    if risk_level == "critical":
        reply = "I'm very concerned about what you just said. Please reach out to a crisis helpline immediately."
    elif len(history) > 0:
        reply = "I see. How long have you felt like this?"
        
    return {
        "reply": reply,
        "risk_level": risk_level,
        "self_harm_detected": self_harm,
        "advice": ["Take a deep breath", "Talk to a friend"] if risk_level != "low" else []
    }

async def summarize_day_llm(answers: list) -> dict:
    """
    Simulate LLM summary of daily check-in answers.
    """
    await asyncio.sleep(0.5)
    
    return {
        "daily_summary": "You seemed to have a challenging day but found some moments of calm.",
        "risk_level": "low", 
        "self_harm_detected": False,
        "advice": ["Get some rest", "Practice mindfulness"]
    }
