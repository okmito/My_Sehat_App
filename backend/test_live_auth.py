
import requests
import json

url = "https://mysehat-gateway.onrender.com/auth/login"
payload = {
    "phone_number": "9876543210",
    "otp": "123456"
}
headers = {
    "Content-Type": "application/json"
}

try:
    print(f"Testing POST {url}")
    response = requests.post(url, json=payload, headers=headers)
    print(f"Status Code: {response.status_code}")
    print(f"Response Text: {response.text}")
except Exception as e:
    print(f"Error: {e}")
