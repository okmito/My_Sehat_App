from fastapi.testclient import TestClient
from diagnostics_backend.diagnostics_app.main import diagnostics_backend.diagnostics_app

client = TestClient(app)

def test_headache_routing():
    print("Testing Headache Routing...")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "I have a sharp headache", "duration": "1 day", "severity": "medium"}
    )
    data = response.json()
    q_text = data["next_question"]["text"].lower()
    print(f"HEADACHE -> Question: {q_text}")
    assert "throbbing" in q_text or "headache" in q_text
    assert "fever" not in q_text
    
def test_vomiting_long_routing():
    print("Testing Vomiting (5 days) Routing...")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "I have been vomiting", "duration": "5 days", "severity": "medium"}
    )
    data = response.json()
    q_text = data["next_question"]["text"].lower()
    print(f"VOMIT (5d) -> Question: {q_text}")
    assert "fever" in q_text
    
def test_general_routing():
    print("Testing General Routing (Weakness)...")
    response = client.post(
        "/api/v1/triage/text",
        json={"symptoms": "I feel weak and tired", "duration": "1 week", "severity": "low"}
    )
    data = response.json()
    q_text = data["next_question"]["text"].lower()
    print(f"GENERAL -> Question: {q_text}")
    assert "describe" in q_text
    assert "fever" not in q_text

if __name__ == "__main__":
    test_headache_routing()
    test_vomiting_long_routing()
    test_general_routing()
    print("ALL CATEGORY ROUTING TESTS PASSED")
