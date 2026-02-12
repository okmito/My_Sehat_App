import os
import json
import re
from pathlib import Path
from typing import Dict, Any, List
from dotenv import load_dotenv

# Load .env from project root (backend folder)
env_path = Path(__file__).resolve().parent.parent.parent.parent / ".env"
load_dotenv(env_path)

try:
    from groq import AsyncGroq
    api_key = os.getenv("GROQ_API_KEY")
    if api_key:
        client = AsyncGroq(api_key=api_key)
        USE_GROQ = True
    else:
        raise ValueError("GROQ_API_KEY not found")
except (ImportError, ValueError) as e:
    print(f"Groq setup error: {e}")
    try:
        from openai import AsyncOpenAI
        client = AsyncOpenAI(api_key=os.getenv("GROQ_API_KEY"))
        USE_GROQ = False
    except ImportError:
        # Fallback: Mock client for development
        class MockClient:
            pass
        client = MockClient()
        USE_GROQ = False
from datetime import datetime

SYSTEM_PROMPT = """You are Mira, a warm and witty mental health companion. Think of yourself as that emotionally intelligent friend who really gets people - you know when to be serious and when a bit of lightness helps.

Your vibe:
- Genuinely empathetic - you FEEL what they're going through
- Naturally curious - you want to understand their world, not just their problems  
- Gently playful - drop a lighthearted comment or gentle humor when it fits (NOT during crisis)
- Real and relatable - share that "been there" energy without making it about you

How you talk:
- Casual but thoughtful - like voice notes between close friends
- Use "honestly", "look", "hey", "okay so", "ngl" naturally
- Short punchy responses (2-4 sentences main reply) - you're texting, not writing essays
- Mirror their energy - if they're casual, you're casual. If they're hurting, you're gentle.
- End with something that keeps the conversation going - an observation, a gentle wondering, or just sitting with them

The conversation flow:
- ALWAYS validate first. "That sounds exhausting" > "Have you tried..."
- Be curious about THEM, not just the problem. "What was that like for you?"
- Make observations that show you get it: "Mood swings are wild like that - one minute you're fine and then boom"
- Use gentle humor to connect when appropriate: "Ah yes, the classic 'I'm fine' while everything is on fire 🙃"
- Ask follow-ups that feel natural, not clinical: "Wait, has this been happening a lot lately?" not "How long have you experienced this?"

What NOT to do:
- Don't be a robot. No "I understand you're feeling X. Let me help."
- Don't rush to fix. Sometimes people just need to vent.
- Don't be preachy. Save the advice unless they're really stuck.
- Don't repeat the same phrases. Keep it fresh.
- Don't be fake positive. "That sucks" is more real than "Stay positive!"

For suggestions (only 2-3, and ONLY when appropriate):
- Make them HYPER-SPECIFIC to what they said
- Frame as ideas, not instructions: "might help to..." not "you should..."
- Include one tiny immediate action: "Put on that one song that always hits"
- Include something slightly unexpected/creative: "Write an angry letter you'll never send"

Humor guidelines:
- Light self-aware humor works: "brains are weird like that"
- Gentle teasing about relatable struggles: "the classic overthinking at 2am specialty"
- Avoid humor during: crisis, grief, serious trauma
- Use humor to build connection, never to minimize

Safety mode (self-harm/crisis):
- Drop the casual tone, be direct and warm
- "Hey, I need to pause here because what you just said matters a lot"
- Prioritize connection over crisis language

Return ONLY valid JSON:
{
  "risk_level": "none | low | medium | high | critical",
  "self_harm_detected": true/false,
  "reply": "your natural, warm response",
  "advice": ["specific thing 1", "specific thing 2"]
}
"""

import random

FALLBACK_RESPONSES = [
    "Hey, I hear you. That sounds like a lot to sit with right now.",
    "Okay, I'm with you. Walk me through what's been going on?",
    "That's real. Sometimes things just hit different and there's no explaining it.",
    "I get it. The mood swing thing is so frustrating - like your brain didn't get the memo.",
    "Honestly, that sounds exhausting. How long have you been carrying this?",
    "Oof. Yeah, that's heavy. I'm here though.",
]

FALLBACK_ADVICE = [
    ["Put on a song that matches exactly how you feel right now", "Text someone 'hey' - you don't need a reason"],
    ["Step outside for literally 2 minutes, just to breathe different air", "Write down one thing that's bugging you - get it out of your head"],
    ["Splash cold water on your face - sounds weird but it resets things", "Name 3 things you can see right now, just to ground yourself"],
]

def extract_json(text: str) -> Dict[str, Any]:
    """
    Robust JSON extraction from LLM output.
    """
    # Clean common issues
    text = text.strip()
    
    # Remove markdown code blocks if present
    if "```json" in text:
        text = text.split("```json")[1].split("```")[0]
    elif "```" in text:
        parts = text.split("```")
        if len(parts) >= 2:
            text = parts[1]
    text = text.strip()
    
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    
    # Attempt repair: find first { and last }
    try:
        start = text.find('{')
        end = text.rfind('}')
        if start != -1 and end != -1 and end > start:
            json_str = text[start:end+1]
            # Fix common escaping issues
            # Handle unescaped quotes in reply text
            json_str = re.sub(r'(?<!\\)"(?=[^:,\[\]{}]*"[,\]}])', '\\"', json_str)
            return json.loads(json_str)
    except (json.JSONDecodeError, AttributeError):
        pass
    
    # Try more flexible regex extraction
    try:
        # Extract reply - handle multiline and various quote escaping
        reply_patterns = [
            r'"reply"\s*:\s*"((?:[^"\\]|\\.)*)"\s*[,}]',
            r'"reply"\s*:\s*"([^"]+)"',
            r"'reply'\s*:\s*'([^']+)'"
        ]
        reply_text = None
        for pattern in reply_patterns:
            match = re.search(pattern, text, re.DOTALL)
            if match:
                reply_text = match.group(1).replace('\\"', '"').replace('\\n', '\n')
                break
        
        if reply_text:
            # Extract other fields
            risk_match = re.search(r'"risk_level"\s*:\s*"(\w+)"', text)
            risk = risk_match.group(1) if risk_match else "low"
            
            sh_match = re.search(r'"self_harm_detected"\s*:\s*(true|false)', text, re.IGNORECASE)
            sh = sh_match.group(1).lower() == 'true' if sh_match else False
            
            # Extract advice array
            advice_match = re.search(r'"advice"\s*:\s*\[(.*?)\]', text, re.DOTALL)
            advice = ["Take a deep breath", "You're doing okay"]
            if advice_match:
                advice_str = advice_match.group(1)
                advice_items = re.findall(r'"([^"]+)"', advice_str)
                if advice_items:
                    advice = advice_items[:3]
            
            return {
                "risk_level": risk,
                "self_harm_detected": sh,
                "reply": reply_text,
                "advice": advice
            }
    except Exception as e:
        print(f"Regex extraction failed: {e}")
    
    # Last resort: just extract any quoted text as reply
    try:
        quotes = re.findall(r'"([^"]{20,})"', text)
        if quotes:
            longest = max(quotes, key=len)
            return {
                "risk_level": "low",
                "self_harm_detected": False,
                "reply": longest,
                "advice": random.choice(FALLBACK_ADVICE)
            }
    except:
        pass
        
    raise ValueError("Could not parse JSON")

def build_fallback_response(user_msg: str) -> Dict[str, Any]:
    return {
        "risk_level": "low",
        "self_harm_detected": False,
        "reply": random.choice(FALLBACK_RESPONSES),
        "advice": random.choice(FALLBACK_ADVICE)
    }

async def analyze_message_llm(user_message: str, conversation_history: List[Dict[str, str]] = None) -> Dict[str, Any]:
    if not os.getenv("GROQ_API_KEY"):
        print("WARNING: GROQ_API_KEY not set, returning fallback")
        return build_fallback_response(user_message)

    try:
        # Build messages with conversation history for context
        messages = [{"role": "system", "content": SYSTEM_PROMPT}]
        
        # Add conversation history (last few exchanges for context)
        if conversation_history:
            for msg in conversation_history[-6:]:  # Last 3 exchanges
                role = "user" if msg.get("role") == "user" else "assistant"
                messages.append({"role": role, "content": msg.get("content", "")})
        
        # Add current message with JSON reminder
        messages.append({"role": "user", "content": f"{user_message}\n\n[Remember: respond ONLY with valid JSON, no other text]"})
        
        completion = await client.chat.completions.create(
            model="llama-3.3-70b-versatile",
            messages=messages,
            temperature=0.75,  # Slightly lower for more reliable JSON
            response_format={"type": "json_object"}  # Force JSON mode
        )
        
        ai_text = completion.choices[0].message.content
        print(f"DEBUG LLM response: {ai_text[:200]}...")  # Debug logging
        return extract_json(ai_text)
        
    except Exception as e:
        print(f"LLM ERROR: {e}")
        return build_fallback_response(user_message)

async def summarize_day_llm(answers: Dict[str, str]) -> Dict[str, Any]:
    """
    Summarize daily check-in answers.
    """
    formatted_answers = "\n".join([f"{k}: {v}" for k, v in answers.items()])
    
    prompt = f"""
    Analyze these daily check-in answers for a user's mental health context:
    {formatted_answers}
    
    Return ONLY valid JSON:
    {{
        "daily_summary": "Short 2-sentence supportive summary of their state",
        "risk_level": "none | low | medium | high | critical",
        "self_harm_detected": true/false,
        "advice": ["advice 1", "advice 2"],
        "reply": "A short comforting message to show immediately"
    }}
    """
    
    try:
        completion = await client.chat.completions.create(
            model="llama-3.1-8b-instant",
            messages=[
                {"role": "system", "content": "You are a compassionate mental health assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=0.4
        )
        ai_text = completion.choices[0].message.content
        return extract_json(ai_text)
    except Exception as e:
        print("LLM SUMMARY ERROR:", e)
        return {
            "daily_summary": "Unable to generate summary at this moment.",
            "risk_level": "medium",
            "self_harm_detected": False,
            "advice": ["Get some rest", "Stay hydrated"],
            "reply": "Thank you for checking in. Take care of yourself today."
        }
