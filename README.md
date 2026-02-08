# MySehat 🏥  
**Offline-First AI-Powered Digital Healthcare Platform**

MySehat is a comprehensive, offline-first digital healthcare and diagnostics platform designed to provide **end-to-end health support through a single mobile application**. It integrates emergency care, mental health support, smart diagnostics, interoperable health records, and health worker enablement—optimized for low-connectivity and last-mile healthcare delivery.

---

## 🚀 Key Objectives
- Enable healthcare access even without internet connectivity
- Reduce emergency response time
- Provide AI-assisted health screening and guidance
- Ensure patient-owned, consent-driven health data
- Support rural and urban healthcare use cases

---

## 🧩 Core Modules

### 1. Emergency Care
- One-tap SOS with live / last-known location  
- Auto alerts to nearest hospitals & ambulances  
- Real-time ambulance tracking  
- Offline-accessible emergency medical profile  

### 2. Mental Health Support
- Anonymous peer support & moderated groups  
- Mood tracking & journaling  
- AI-based mental health screening  
- Guided exercises and stress-relief activities  
- Voice and chat-based support  

### 3. Smart Diagnostics
- AI symptom checker (survey + triage)  
- Image-based screening (skin, wounds, reports)  
- Teleradiology and pathology uploads  
- Integration-ready for portable diagnostic devices  

### 4. Interoperable Health Records
- Unified longitudinal health record  
- FHIR-based data exchange  
- Patient-controlled consent for data sharing  

### 5. Health Worker Mode
- Offline field data collection  
- Household surveys and follow-ups  
- Geo-tagged visits  
- Automatic sync when connectivity is restored  

### 6. Utilities
- Medicine reminders & e-prescriptions  
- Health analytics dashboard  
- Insurance & government scheme linkage  
- Multilingual UI with voice assistance  

### 7. Platform Core
- Offline-first architecture  
- AI-powered backend and chatbot  
- Secure, patient-owned data  
- Scalable and interoperable system  

---

## 🏗️ Tech Stack (Suggested)

### Frontend
- Flutter (Android-first)
- Offline local storage (SQLite / Isar / Hive)
- State management: BLoC / Riverpod

### Backend
- Python (FastAPI)
- REST APIs + WebSockets
- AI inference services
- PostgreSQL + Redis
- Object storage for images/reports

### AI & ML
- Symptom triage models
- Mental health screening models
- Image classification (skin/wounds/reports)
- NLP-based chatbot
- Multilingual voice support

---

## 🔐 Security & Compliance
- End-to-end encryption
- Role-based access control
- Patient-controlled consent
- Immutable audit logs
- Data minimization and privacy-first design

---

## 🌐 Render Deployment (Gateway Architecture)

MySehat uses a gateway-based architecture where multiple internal services are orchestrated behind a single public endpoint, making it compatible with Render's single-port deployment model.

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    RENDER (Internet)                        │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Gateway (0.0.0.0:$PORT)                   │   │
│  │              PUBLIC ENTRY POINT                      │   │
│  └─────────────────┬───────────────────────────────────┘   │
│                    │                                        │
│    ┌───────────────┼───────────────────────────────────┐   │
│    │               │ Internal Services (127.0.0.1)     │   │
│    │               ▼                                    │   │
│    │  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ │   │
│    │  │Auth:8001│ │Diag:8002│ │Med:8003 │ │MH:8004  │ │   │
│    │  └─────────┘ └─────────┘ └─────────┘ └─────────┘ │   │
│    │  ┌─────────┐ ┌─────────┐ ┌─────────┐             │   │
│    │  │SOS:8005 │ │FHIR:8006│ │HR:8007  │             │   │
│    │  └─────────┘ └─────────┘ └─────────┘             │   │
│    └────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Why Gateway is the Only Exposed Service

1. **Render Constraint**: Render free tier allows only ONE public port
2. **Security**: Internal services are not directly accessible from the internet
3. **Centralized Concerns**: Authentication, DPDP consent, and audit logging happen at gateway level
4. **Simplified Client Integration**: Flutter app and Hospital website use a single base URL

### Render-Safe Start Command

```bash
python start_all_backends.py
```

This command:
1. Starts all internal services on `127.0.0.1:800X` (localhost only)
2. Starts the gateway on `0.0.0.0:$PORT` (Render's assigned port)
3. Gateway reverse-proxies all requests to internal services

### Render Deployment Steps

1. **Push to GitHub**:
   ```bash
   git add .
   git commit -m "Render-ready gateway architecture"
   git push origin main
   ```

2. **Create Render Web Service**:
   - Go to [Render Dashboard](https://dashboard.render.com)
   - Click "New +" → "Web Service"
   - Connect your GitHub repository
   - Configure:
     - **Name**: `mysehat-gateway`
     - **Root Directory**: `backend`
     - **Environment**: `Python 3`
     - **Build Command**: `pip install -r requirements.txt`
     - **Start Command**: `python start_all_backends.py`

3. **Set Environment Variables** (in Render dashboard):
   ```
   GROQ_API_KEY=your_groq_api_key
   JWT_SECRET_KEY=your_secret_key
   ```

4. **Update Client Applications**:
   - **Flutter App**: Update `API_BASE_URL` to `https://mysehat-gateway.onrender.com`
   - **Hospital Website**: Update API base URL to the same gateway URL

### Local Development

Test locally before deploying:

```bash
cd backend
pip install -r requirements.txt
python start_all_backends.py
```

API will be available at:
- Gateway: `http://localhost:8000`
- Swagger Docs: `http://localhost:8000/docs`
- Health Check: `http://localhost:8000/health`

### API Routes (via Gateway)

| Service | Gateway Route | Internal Port |
|---------|--------------|---------------|
| Auth | `/auth/*` | 127.0.0.1:8001 |
| Diagnostics | `/diagnostics/*` | 127.0.0.1:8002 |
| Medicine | `/medicine-reminder/*` | 127.0.0.1:8003 |
| Mental Health | `/mental-health/*` | 127.0.0.1:8004 |
| SOS Emergency | `/sos/*` | 127.0.0.1:8005 |
| FHIR R4 | `/fhir/*` | 127.0.0.1:8006 |
| Health Records | `/health-records/*` | 127.0.0.1:8007 |
| DPDP Consent | `/api/v1/consent` | (Gateway) |

---

## 🧪 Hackathon MVP Scope
- Offline-first mobile app
- SOS emergency flow
- AI symptom checker (rule-based)
- Mental health chatbot
- Unified patient profile
- Multilingual voice-ready UI

---

## 📌 Future Enhancements
- Full FHIR interoperability
- Real ambulance and hospital integrations
- Advanced AI models
- Wearable and IoT device support
- Large-scale analytics and dashboards

---

## 🤝 Contribution
This project is designed to be modular and scalable. Contributions for new features, bug fixes, or documentation improvements are welcome.

---

## 📄 License
This project is intended for educational, hackathon, and research purposes. Licensing can be defined based on deployment needs.

---

**MySehat – Healthcare that works everywhere.**
