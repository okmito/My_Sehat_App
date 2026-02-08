import asyncio
from diagnostics_backend.diagnostics_app.services.vision_service import VisionService
from diagnostics_backend.diagnostics_app.services.reasoning_service import ReasoningService

async def test_stubs():
    print("Testing Vision Service Stub...")
    vision = VisionService()
    # Mock image bytes
    result = await vision.analyze_image(b"fake_image_bytes")
    print(f"Vision Result: {result.keys()}")
    assert "observations" in result
    assert "vision_confidence" in result

    print("Testing Reasoning Service Stub...")
    reasoning = ReasoningService()
    session_data = {"symptoms": "itchy skin"}
    
    # Test Question Generation
    q_result = await reasoning.generate_question(session_data)
    print(f"Question Result: {q_result.keys()}")
    assert "question_text" in q_result

    # Test Final Analysis
    a_result = await reasoning.analyze_symptoms(session_data)
    print(f"Analysis Result: {a_result.keys()}")
    assert "possible_causes" in a_result
    print("AI Services Stubs Verification Successful!")

if __name__ == "__main__":
    asyncio.run(test_stubs())
