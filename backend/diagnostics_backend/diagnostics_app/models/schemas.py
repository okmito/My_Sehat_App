from pydantic import BaseModel
from typing import List, Optional, Any, Dict
from datetime import datetime

class MessageBase(BaseModel):
    sender: str
    content: str

class MessageCreate(MessageBase):
    pass

class Message(MessageBase):
    id: int
    session_id: str
    created_at: datetime

    class Config:
        from_attributes = True

class SessionCreate(BaseModel):
    language: str = "en"

class SessionResponse(BaseModel):
    id: str
    status: str
    language: str
    created_at: datetime
    messages: List[Message] = []

    class Config:
        from_attributes = True

class TriageInputText(BaseModel):
    symptoms: str
    age: Optional[int] = None
    duration: Optional[str] = None
    severity: Optional[str] = None

class AnswerInput(BaseModel):
    answer: str

class Question(BaseModel):
    id: str
    text: str
    options: List[str]
    allow_custom: bool
    
    model_config = {"from_attributes": True}

class TriageOutputSchema(BaseModel):
    summary: str
    severity: str
    possible_causes: List[Dict[str, Any]]
    home_care: List[str]
    prevention: List[str]
    red_flags: List[str]
    when_to_seek_care: List[str]
    disclaimer: str
    
    model_config = {"from_attributes": True}

class TriageResponse(BaseModel):
    session_id: str
    status: str  # needs_more_info | completed
    next_question: Optional[Question] = None
    final_output: Optional[TriageOutputSchema] = None
    
    model_config = {"from_attributes": True}
