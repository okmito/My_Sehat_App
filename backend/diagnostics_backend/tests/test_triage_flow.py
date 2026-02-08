from fastapi.testclient import TestClient
from diagnostics_backend.diagnostics_app.main import app
from diagnostics_backend.diagnostics_app.db.session import SessionLocal

# Dependency override not strictly needed if using SQLite for both, 
# but good practice. For now, running against the dev DB (file).

client = TestClient(app)

def test_triage_text_flow():
    print("Testing POST /triage/text")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "itchy skin", "duration": "2 days"}
    )
    assert response.status_code == 200
    data = response.json()
    print(f"Response keys: {data.keys()}")
    
    if data["status"] == "completed":
        assert "final_output" in data
        assert "summary" in data["final_output"]
        assert "possible_causes" in data["final_output"]
    else:
        assert data["status"] == "needs_more_info"
        assert data["next_question"] is not None
    
def test_triage_safety_block():
    print("Testing Safety Block")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "severe chest pain and I want to die"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["final_output"]["severity"] == "high"
    assert "CRITICAL SAFETY ALERT" in data["final_output"]["summary"]

def test_triage_image_flow():
    print("Testing POST /triage/image")
    # minimal fake image
    files = {"file": ("test.jpg", b"fakebytes", "image/jpeg")}
    response = client.post("/api/v1/triage/image", files=files)
    assert response.status_code == 200
    data = response.json()
    print(f"Image Response keys: {data.keys()}")
    assert "possible_causes" in data



def test_image_session_flow():
    print("Testing Image Session Flow (Multi-turn)")
    
    # 1. Upload first image
    files = {"file": ("test1.jpg", b"fakebytes1", "image/jpeg")}
    response = client.post("/api/v1/triage/image", files=files)
    assert response.status_code == 200
    data = response.json()
    
    session_id = data["session_id"]
    assert data["status"] == "needs_more_info"
    assert data["next_question"]["id"] == "q_continue_1"
    
    print(f"Session started: {session_id}")
    
    # 2. Answer "Yes, upload another image"
    response = client.post(
        f"/api/v1/triage/session/{session_id}/answer",
        json={"answer": "Yes, upload another image"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "needs_more_info"
    
    # 3. Upload second image (pass session_id)
    files = {"file": ("test2.jpg", b"fakebytes2", "image/jpeg")}
    response = client.post(
        "/api/v1/triage/image", 
        files=files,
        data={"session_id": session_id}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["session_id"] == session_id
    assert data["status"] == "needs_more_info" # Should still ask confirmation
    
    # 4. Add text symptoms
    response = client.post(
        f"/api/v1/triage/session/{session_id}/text",
        json={"symptoms": "It also hurts when I touch it"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "needs_more_info"
    
    # 5. Finalize
    response = client.post(
        f"/api/v1/triage/session/{session_id}/answer",
        json={"answer": "No, finalize now"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "completed"
    assert data["final_output"] is not None
    print("Session finalized successfully")

if __name__ == "__main__":
    test_triage_text_flow()
    test_triage_safety_block()
    # test_triage_image_flow() 
    test_image_session_flow()
    print("ALL TESTS PASSED")
