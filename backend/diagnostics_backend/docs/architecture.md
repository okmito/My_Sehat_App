# System Architecture

## Overview
This backend provides AI-assisted symptom triage using a "Vision -> Reasoning" pipeline.
It is explicitly designed NOT to provide medical diagnoses.

## Modules
- **app/api**: FastAPI route handlers.
- **app/core**: Configuration and settings.
- **app/services**: Business logic.
    - `vision_service.py`: Image analysis.
    - `reasoning_service.py`: LLM reasoning.
    - `triage_orchestrator.py`: Flow control.
    - `safety_service.py`: Guardrails.
- **app/db**: Database models and connection.
- **app/models**: Pydantic schemas.

## Data Flow
1. **Input**: User submits text or image.
2. **Vision**: (If image) Extracts observations (e.g., "redness").
3. **Reasoning**: LLM suggests possible causes based on observations/text.
4. **Safety**: Deterministic rules check for emergencies.
5. **Output**: Structured JSON with triage advice.
