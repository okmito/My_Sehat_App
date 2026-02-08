from fastapi.testclient import TestClient
from diagnostics_backend.diagnostics_app.main import diagnostics_backend.diagnostics_app

client = TestClient(app)

def test_text_triage_strictness():
    print("Testing Text Triage Strictness (Vomiting)...")
    # Even if we say "skin" in text, strictly enforced text-mode might 
    # default to Systemic based on the stub logic, OR if we say "vomiting" 
    # it definitely should be systemic.
    # The requirement was: "Text-only triage must NEVER ask skin or rash questions"
    
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "I have been vomiting for 5 days"}
    )
    data = response.json()
    
    assert data["status"] == "needs_more_info"
    question_text = data["next_question"]["text"].lower()
    
    print(f"Received Question: {question_text}")
    
    # Assert it is NOT skin related
    assert "itchy" not in question_text
    assert "rash" not in question_text
    
    # Assert it IS systemic related
    assert "fever" in question_text or "dehydration" in question_text
    print("Text Triage Strictness Passed")


def test_wound_image_strictness():
    print("Testing Wound Image Strictness...")
    # Mock Odd Bytes -> Wound in VisionService stub
    fake_img = b"12345" 
    files = {"file": ("wound.jpg", fake_img, "image/jpeg")}
    
    # NOTE: Logic in orchestrator currently finalizes immediately for wounds,
    # skipping questions. Let's verify it finalizes with WOUND diagnosis.
    response = client.post("/api/v1/triage/image", files=files)
    data = response.json()
    
    assert data["status"] == "completed"
    summary = data["final_output"]["summary"].lower()
    print(f"Received Summary: {summary}")
    
    assert "wound" in summary
    assert "skin" not in summary
    print("Wound Image Strictness Passed")

if __name__ == "__main__":
    test_text_triage_strictness()
    test_wound_image_strictness()
    print("ALL DOMAIN STRICTNESS TESTS PASSED")
