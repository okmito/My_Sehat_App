import sys
from pathlib import Path
from typing import Dict, Any, Optional
from sqlalchemy.orm import Session

# Add parent directory to path
# Add backend directory to path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent.parent))

from services.vision_service import VisionService
from services.reasoning_service import ReasoningService, CONFIRMATION_QUESTION, GENERAL_QUESTIONS
from services.safety_service import SafetyService
from services.session_service import SessionService
from diagnostics_backend.diagnostics_app.models.schemas import SessionCreate, MessageCreate, TriageResponse, Question, TriageOutputSchema
from diagnostics_backend.diagnostics_app.db.models import TriageSession

class TriageOrchestrator:
    def __init__(self, db: Session):
        self.db = db
        self.session_service = SessionService(db)
        self.vision = VisionService()
        self.reasoning = ReasoningService()
        self.safety = SafetyService()

    async def create_session(self, language: str = "en") -> TriageSession:
        return self.session_service.create_session(SessionCreate(language=language))

    async def get_session(self, session_id: str) -> Optional[TriageSession]:
        return self.session_service.get_session(session_id)

    def _build_context(self, session: TriageSession, current_input: str = "", input_mode: str = "mixed", severity: str = None, duration: str = None) -> Dict[str, Any]:
        """Combine symptoms, history, and observations."""
        combined_text = current_input
        # Add history (simplified)
        for msg in session.messages:
            if msg.sender == "user":
                combined_text += f"\n{msg.content}"
        
        observations = {}
        if session.observations:
             # Just take the last one for now
             observations = session.observations[-1].observation_data

        return {
            "symptoms": combined_text,
            "observations": observations,
            "question_count": len([m for m in session.messages if m.sender == "ai"]),
            "input_mode": input_mode, # text, image, mixed
            "severity": severity,
            "duration": duration
        }

    async def _decide_next_step(self, session_id: str, context: Dict[str, Any]) -> TriageResponse:
        """Core decision loop: Question or Final?"""
        # 1. Check Safety AGAIN (on combined text)
        unsafe = self.safety.check_safety(context["symptoms"])
        if unsafe:
            return TriageResponse(
                session_id=session_id,
                status="completed",
                final_output=TriageOutputSchema(**unsafe)
            )

        # 2. Reasoning Logic (Stubbed heuristics)
        # If we have an image with an open wound, we finalize immediately.
        obs = context.get("observations", {}).get("observations", [])
        if "open wound" in obs:
             result = await self.reasoning.analyze_symptoms(context)
             return TriageResponse(session_id=session_id, status="completed", final_output=TriageOutputSchema(**result))

        # If text only (no observations) and question_count == 0 -> Ask Question
        if not context["observations"] and context["question_count"] == 0:
            question = await self.reasoning.generate_question(context)
            # Log question as AI message provided we have a robust way to do so, 
            # or just return it. For session state, best to add it.
            self.session_service.add_message(session_id, MessageCreate(sender="ai", content=question.text))
            
            return TriageResponse(
                session_id=session_id,
                status="needs_more_info",
                next_question=question
            )

        # Default: Finalize - ensure input_mode is preserved for proper categorization
        if not context["observations"]:
            context["input_mode"] = "text"  # Force text mode if no images
        result = await self.reasoning.analyze_symptoms(context)
        return TriageResponse(
            session_id=session_id,
            status="completed",
            final_output=TriageOutputSchema(**result)
        )

    async def process_text_triage(self, session_id: str, symptoms: str, severity: Optional[str] = None, duration: Optional[str] = None) -> TriageResponse:
        # 1. Save User Input
        self.session_service.add_message(session_id, MessageCreate(sender="user", content=symptoms))
        
        # 2. Build Context needed for decision
        session = await self.get_session(session_id) # reload to get relationships
        if not session:
            # Should not happen if called correctly
             raise ValueError("Session not found")
        
        context = self._build_context(session, symptoms, input_mode="text", severity=severity, duration=duration) 
        
        # 3. Decide
        return await self._decide_next_step(session_id, context)

    async def process_image_triage(self, session_id: Optional[str], image_bytes: bytes) -> TriageResponse:
        # 0. Ensure Session
        if not session_id:
            session = await self.create_session()
            session_id = session.id
        
        # 1. Vision Processing
        vision_result = await self.vision.analyze_image(image_bytes)
        self.session_service.add_observation(session_id, "vision", vision_result)
        
        # 2. Context
        session = await self.get_session(session_id)
        context = self._build_context(session, input_mode="image")
        
        # 3. Return Confirmation (Multi-turn flow)
        # We do NOT finalize here. We ask if they want to continue.
        return TriageResponse(
            session_id=session_id,
            status="needs_more_info",
            next_question=CONFIRMATION_QUESTION
        )

    async def process_answer(self, session_id: str, answer: str) -> TriageResponse:
        # 1. Save Answer
        self.session_service.add_message(session_id, MessageCreate(sender="user", content=answer))
        
        # 2. Context - preserve text mode if no images were uploaded
        session = await self.get_session(session_id)
        has_observations = session.observations and len(session.observations) > 0
        input_mode = "mixed" if has_observations else "text"
        context = self._build_context(session, input_mode=input_mode)
        
        # 3. Logic based on Answer
        # "Yes, upload another image", "Yes, add symptoms in text", "No, finalize now"
        
        ans_lower = answer.lower()
        
        if "upload another image" in ans_lower:
             # User wants to upload. We return needs_more_info and maybe a null question or the same confirmation 
             # to keep state "valid". But effectively we are waiting for /image call.
             # Let's return the confirmation again (or a variant) specifically asking for image? 
             # For now, per spec "next_question can be null or 'upload image now'"
             return TriageResponse(
                 session_id=session_id,
                 status="needs_more_info",
                 next_question=Question(id="q_upload_prompt", text="Please upload the next image.", options=[], allow_custom=False)
             )
             
        if "add symptoms" in ans_lower:
            # User wants to add text. Ask generic text question.
            return TriageResponse(
                 session_id=session_id,
                 status="needs_more_info",
                 next_question=GENERAL_QUESTIONS[0] # "Can you describe your symptoms...?"
             )
             
        if "finalize" in ans_lower or "no" in ans_lower:
            # Finalize.
            result = await self.reasoning.analyze_symptoms(context)
            return TriageResponse(
                session_id=session_id,
                status="completed",
                final_output=TriageOutputSchema(**result)
            )
            
        # Fallback if unknown answer -> Standard Logic
        return await self._decide_next_step(session_id, context)

    async def process_session_text(self, session_id: str, symptoms: str, **kwargs) -> TriageResponse:
        """
        Add text symptoms to existing session and return Confirmation.
        """
        # 1. Save User Input
        self.session_service.add_message(session_id, MessageCreate(sender="user", content=symptoms))
        
        # 2. Return Confirmation directly (as per spec)
        return TriageResponse(
            session_id=session_id,
            status="needs_more_info", 
            next_question=CONFIRMATION_QUESTION
        )
