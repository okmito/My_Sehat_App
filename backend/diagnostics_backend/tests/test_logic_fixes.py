from fastapi.testclient import TestClient
from diagnostics_backend.diagnostics_app.main import diagnostics_backend.diagnostics_app

client = TestClient(app)

def test_systemic_routing():
    print("Testing Systemic Routing (Fever)...")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "I have a high fever and headache"}
    )
    assert response.status_code == 200
    data = response.json()
    
    # Expect: Needs info (Question) OR Systemic Output
    # Stub logic: Text only -> Needs info first.
    assert data["status"] == "needs_more_info"
    assert "fever" in data["next_question"]["text"].lower()
    
    # Answer the question to finalize
    session_id = data["session_id"]
    ans_response = client.post(
        f"/api/v1/triage/session/{session_id}/answer",
        json={"answer": "Fever started 2 days ago"}
    )
    ans_data = ans_response.json()
    assert ans_data["status"] == "completed"
    assert "viral" in ans_data["final_output"]["summary"].lower()
    print("Systemic Routing Passed")

def test_skin_routing():
    print("Testing Skin Routing (Rash)...")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "I have an itchy rash"}
    )
    data = response.json()
    assert data["status"] == "needs_more_info"
    assert "itchy" in data["next_question"]["text"].lower() or "rash" in data["next_question"]["text"].lower()
    
    session_id = data["session_id"]
    ans_response = client.post(
        f"/api/v1/triage/session/{session_id}/answer",
        json={"answer": "It is very itchy"}
    )
    ans_data = ans_response.json()
    assert ans_data["status"] == "completed"
    assert "dermatitis" in ans_data["final_output"]["possible_causes"][0]["name"].lower()
    print("Skin Routing Passed")

def test_wound_vision_routing():
    print("Testing Wound Vision Routing (Odd Bytes)...")
    # Mock Odd Bytes -> Wound in VisionService stub
    fake_img = b"12345" # len 5 (odd)
    files = {"file": ("wound.jpg", fake_img, "image/jpeg")}
    
    response = client.post("/api/v1/triage/image", files=files)
    data = response.json()
    
    # Vision logic: if open wound -> complete immediately
    assert data["status"] == "completed"
    assert "wound" in data["final_output"]["summary"].lower()
    assert "laceration" in data["final_output"]["possible_causes"][0]["name"].lower()
    print("Wound Vision Routing Passed")

def test_rash_vision_routing():
    print("Testing Rash Vision Routing (Even Bytes)...")
    # Mock Even Bytes -> Rash in VisionService stub
    fake_img = b"1234" # len 4 (even)
    files = {"file": ("rash.jpg", fake_img, "image/jpeg")}
    
    response = client.post("/api/v1/triage/image", files=files)
    data = response.json()
    
    # Current stub logic for skin image might also complete, 
    # but let's check it returns skin diagnosis
    assert data["status"] == "completed" 
    assert "skin" in data["final_output"]["summary"].lower()
    assert "dermatitis" in data["final_output"]["possible_causes"][0]["name"].lower()
    print("Rash Vision Routing Passed")

if __name__ == "__main__":
    test_systemic_routing()
    test_skin_routing()
    test_wound_vision_routing()
    test_rash_vision_routing()
    print("ALL LOGIC FIXES PASSED")
