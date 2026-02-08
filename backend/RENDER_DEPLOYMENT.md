# MySehat Backend - Render Deployment Guide

## Overview

MySehat uses a **gateway-based architecture** where multiple internal FastAPI services are orchestrated behind a single public endpoint. This architecture is specifically designed for Render's free tier which **only allows ONE public port**.

## Architecture Explanation

```
Internet → Render (0.0.0.0:$PORT)
              │
              ▼
         ┌─────────┐
         │ Gateway │ ← The ONLY public service
         └────┬────┘
              │
    ┌─────────┴─────────┐
    │    localhost      │
    ▼         ▼         ▼
┌──────┐ ┌──────┐ ┌──────┐
│:8001 │ │:8002 │ │:8003 │  ... Internal services
│ Auth │ │Diag  │ │ Med  │      (NOT accessible from internet)
└──────┘ └──────┘ └──────┘
```

### Key Principles

1. **Gateway is the ONLY service that binds to 0.0.0.0**
   - This makes it accessible from the internet
   - Render sets the `$PORT` environment variable

2. **All other services bind to 127.0.0.1**
   - These are internal services
   - Only the gateway can reach them
   - They are NOT accessible from outside the machine

3. **NO hard-coded ports exposed externally**
   - Internal ports (8001-8007) are localhost only
   - External port comes from `$PORT`

## Deployment Steps

### 1. Push Code to GitHub

```bash
git add .
git commit -m "Render-ready gateway architecture"
git push origin main
```

### 2. Create Render Web Service

1. Go to [Render Dashboard](https://dashboard.render.com)
2. Click **"New +"** → **"Web Service"**
3. Connect your GitHub repository

### 3. Configure Service Settings

| Setting | Value |
|---------|-------|
| **Name** | `mysehat-gateway` |
| **Region** | Oregon (or your preferred) |
| **Branch** | `main` |
| **Root Directory** | `backend` |
| **Runtime** | Python 3 |
| **Build Command** | `pip install -r requirements.txt` |
| **Start Command** | `python start_all_backends.py` |
| **Plan** | Free |

### 4. Set Environment Variables

In Render dashboard → Your service → **Environment**:

| Variable | Value | Notes |
|----------|-------|-------|
| `GROQ_API_KEY` | `your_api_key` | Required for AI features |
| `JWT_SECRET_KEY` | (auto-generate) | Click "Generate" button |
| `PYTHONPATH` | `/opt/render/project/src/backend` | For imports |

### 5. Deploy

Click **"Create Web Service"**. Render will:
1. Clone your repository
2. Install dependencies
3. Run `python start_all_backends.py`
4. Expose the gateway on a public URL

### 6. Verify Deployment

Once deployed, test these endpoints:

```bash
# Health check
curl https://your-service.onrender.com/health

# API documentation
open https://your-service.onrender.com/docs

# Service status
curl https://your-service.onrender.com/services
```

## Local Testing

Always test locally before deploying:

```bash
cd backend
pip install -r requirements.txt
python start_all_backends.py
```

Expected output:
```
============================================================
MySehat Multi-Backend Orchestrator
Render-Compatible Single-Port Architecture
============================================================

[1/2] Starting internal services (localhost only)...

  Starting Auth Backend on 127.0.0.1:8001...
  Starting Diagnostics Backend on 127.0.0.1:8002...
  Starting Medicine Backend on 127.0.0.1:8003...
  Starting Mental Health Backend on 127.0.0.1:8004...
  Starting SOS Backend on 127.0.0.1:8005...
  Starting FHIR Backend on 127.0.0.1:8006...
  Starting Health Records Backend on 127.0.0.1:8007...

⏳ Waiting for internal services to initialize...

[2/2] Starting public gateway...

============================================================
Starting Gateway on 0.0.0.0:8000 (PUBLIC)
============================================================

✅ MySehat Backend Stack Started Successfully!
```

## Updating Client Applications

### Flutter App

Update [`lib/core/config/api_config.dart`](../lib/core/config/api_config.dart):

```dart
class ApiConfig {
  static const String baseUrl = 'https://mysehat-gateway.onrender.com';
  // ...
}
```

### Hospital Website

Update your API base URL configuration:

```javascript
const API_BASE_URL = 'https://mysehat-gateway.onrender.com';
```

## API Route Reference

| Client Route | Gateway Path | Internal Service |
|--------------|--------------|------------------|
| Login | `POST /auth/login` | auth:8001 |
| Signup | `POST /auth/signup` | auth:8001 |
| Symptom Check | `POST /diagnostics/triage` | diagnostics:8002 |
| Medications | `GET /medicine-reminder/medications` | medicine:8003 |
| Mental Health Chat | `POST /mental-health/chat/message` | mental-health:8004 |
| SOS Trigger | `POST /sos/trigger` | sos:8005 |
| FHIR Patient | `GET /fhir/Patient/{id}` | fhir:8006 |
| Health Records | `GET /health-records/records` | health-records:8007 |
| DPDP Consent | `GET /api/v1/consent` | (gateway) |

## Troubleshooting

### Service Unavailable (503)

If you get 503 errors, an internal service failed to start:

1. Check Render logs for startup errors
2. Verify all environment variables are set
3. Check if the service module path is correct in `start_all_backends.py`

### Gateway Timeout (504)

Internal services may be slow to respond:

1. Increase timeout in gateway (default: 30s)
2. Check if the internal service is healthy
3. Look for database connection issues

### CORS Errors

Gateway handles CORS. Ensure your client origin is allowed:

```python
# In gateway/main.py
allow_origins=["*"]  # Or specific origins for production
```

### AI Features Not Working

Check `GROQ_API_KEY` environment variable:

1. Verify it's set in Render dashboard
2. Check it's not expired
3. See `GROQ_SETUP.md` for getting an API key

## Production Recommendations

For production deployment:

1. **Use a proper database** (PostgreSQL instead of SQLite)
2. **Set specific CORS origins** (not `*`)
3. **Enable HTTPS only**
4. **Set up monitoring** (Render provides basic metrics)
5. **Configure auto-restart** on failure
6. **Use Render's managed database** for persistence

---

"MySehat uses a gateway-based architecture where multiple internal services are orchestrated behind a single public endpoint, making it compatible with Render's single-port deployment model."
