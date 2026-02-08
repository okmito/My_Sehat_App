from fastapi.testclient import TestClient
from diagnostics_backend.diagnostics_app.main import diagnostics_backend.diagnostics_app

client = TestClient(app)

def test_gi_gate():
    print("Testing GI Gate (Uneasy Stomach, 1 day, Low)...")
    response = client.post(
        "/api/v1/triage/text",
        json={
            "symptoms": "I feel uneasy in my stomach", 
            "duration": "1 day",
            "severity": "low"
        }
    )
    data = response.json()
    assert data["status"] == "needs_more_info"
    question_text = data["next_question"]["text"].lower()
    print(f"Question: {question_text}")
    
    # Expect: GI question
    assert "nausea" in question_text or "vomiting" in question_text
    assert "fever" not in question_text
    print("GI Gate Passed")

def test_fever_override():
    print("Testing Fever Override (Fever + Stomach)...")
    # Even if stomach mentioned, Fever keyword should force Fever question
    response = client.post(
        "/api/v1/triage/text",
        json={
            "symptoms": "I have fever and stomach ache", 
            "duration": "1 day",
            "severity": "low"
        }
    )
    data = response.json()
    question_text = data["next_question"]["text"].lower()
    print(f"Question: {question_text}")
    
    # Expect: Fever question
    assert "fever" in question_text
    print("Fever Override Passed")

if __name__ == "__main__":
    test_gi_gate()
    test_fever_override()
    print("ALL GI LOGIC TESTS PASSED")
