# MySehat – Diagnostics Backend (Symptom Checker & Image Triage)

## How to test in Swagger
1. **Initial Image Upload**: use `POST /api/v1/triage/image`. Upload an image. 
   - Observe `session_id` and `status="needs_more_info"`.
2. **Continue Session**: use `POST /api/v1/triage/session/{session_id}/answer`.
   - Body: `{"answer": "Yes, upload another image"}`.
3. **Upload Second Image**: use `POST /api/v1/triage/image`.
   - Upload file AND provide `session_id` in form data.
4. **Add Text**: use `POST /api/v1/triage/session/{session_id}/text`.
   - Body: `{"symptoms": "pain"}`.
5. **Finalize**: use `POST /api/v1/triage/session/{session_id}/answer`.
   - Body: `{"answer": "No, finalize now"}`.
   - Observe `final_output`.

## Purpose
Backend for AI-assisted symptom triage.
This system does NOT provide medical diagnosis.

## Core Capabilities
- Text-based symptom checking
- Image-based observation extraction (skin, wounds)
- AI-assisted triage with follow-up questions
- Structured output with confidence scores
- Temporary image storage with deletion
- Multilingual-ready responses

## Design Constraints
- Option B architecture (Vision → Observations → Reasoning)
- Python backend
- Internet allowed
- No Google Image Search or scraping
- No medical diagnosis claims
- Safety & disclaimer mandatory

## Target Users
- Urban smartphone users
- Rural / low-literacy users

## Out of Scope
- Hospital integrations
- Wearables
- Offline inference