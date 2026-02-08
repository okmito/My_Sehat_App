# MySehat Integrated Healthcare Gateway

## Overview

The Gateway is a **pure composition layer** that unifies three independent FastAPI backends into a single, cohesive healthcare platform accessible through **ONE port and ONE Swagger UI**.

### Architecture

```
┌─────────────────────────────────────────────────────────┐
│           MySehat Gateway Application                   │
│                    (Port 8000)                          │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │
│  │ Diagnostics  │  │ Mental Health │  │   Medicine   │ │
│  │   Backend    │  │    Backend    │  │   Backend    │ │
│  │              │  │               │  │              │ │
│  │ /diagnostics │  │ /mental-health│  │/medicine-   │ │
│  │              │  │               │  │reminder      │ │
│  └──────────────┘  └──────────────┘  └──────────────┘ │
│                                                         │
└─────────────────────────────────────────────────────────┘
         ↓
    Swagger UI: /docs
```

---

## Features

✅ **Unified API Gateway**
- Single FastAPI app
- Single port (8000)
- One Swagger UI at `/docs`

✅ **Domain Isolation**
- `/diagnostics/*` - Symptom analysis and triage
- `/mental-health/*` - Mental health screening and crisis detection
- `/medicine-reminder/*` - Prescription and medication management

✅ **Clear Swagger Grouping**
- Endpoints organized by domain/tag
- No route duplication
- No cross-domain contamination

✅ **Preserved Backend Logic**
- No modifications to backend code
- All AI/ML models intact
- Database connections preserved

✅ **Extensible Design**
- Add new backends with 2–3 lines of code
- No breaking changes to existing backends

---

## Installation

### 1. Install Dependencies

```bash
pip install -r gateway/requirements.txt
```

### 2. Verify Installation

```bash
# Check all routes are loaded
python gateway/test_startup.py

# View all endpoints by tag
python gateway/test_routes.py
```

---

## Running the Gateway

### Start the Gateway Server

```bash
cd c:\Honey\Projects\My_Sehat\BACKEND

uvicorn gateway.main:gateway_app --reload --port 8000
```

**Output:**
```
INFO:     Uvicorn running on http://127.0.0.1:8000
INFO:     Application startup complete
```

### Access the Gateway

| Resource | URL |
|----------|-----|
| **Swagger UI** | http://localhost:8000/docs |
| **ReDoc** | http://localhost:8000/redoc |
| **OpenAPI JSON** | http://localhost:8000/openapi.json |
| **Health Check** | http://localhost:8000/health |

---

## API Endpoints

### Diagnostics (`/diagnostics`)

AI-powered symptom triage and analysis.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/diagnostics/triage/text` | Analyze symptoms from text |
| `POST` | `/diagnostics/triage/image` | Analyze symptoms from image |
| `POST` | `/diagnostics/triage/session/{id}/text` | Continue triage session with text |
| `GET` | `/diagnostics/triage/session/{id}` | Get triage session details |

### Mental Health (`/mental-health`)

Mental health screening and crisis detection.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `POST` | `/mental-health/chat/message` | Chat with AI agent and get risk assessment |
| `GET` | `/mental-health/checkin/today` | Get daily check-in questions |
| `POST` | `/mental-health/checkin/submit` | Submit check-in responses |
| `GET` | `/mental-health/health` | Service health check |

### Medicine Reminder (`/medicine-reminder`)

Prescription and medication management.

| Method | Endpoint | Purpose |
|--------|----------|---------|
| **Medications** | | |
| `POST` | `/medicine-reminder/medications/` | Create medication |
| `GET` | `/medicine-reminder/medications/` | List medications |
| `GET` | `/medicine-reminder/medications/{id}` | Get medication details |
| **Reminders** | | |
| `POST` | `/medicine-reminder/reminders/generate` | Generate dose reminders |
| `GET` | `/medicine-reminder/reminders/today` | Get today's reminders |
| `GET` | `/medicine-reminder/reminders/next` | Get next reminders |
| **Prescriptions** | | |
| `GET` | `/medicine-reminder/prescriptions/` | List prescriptions |
| `POST` | `/medicine-reminder/prescriptions/upload` | Upload prescription |

---

## Gateway Implementation Details

### How Composition Works

#### 1. **Diagnostics Backend**
- **Original:** `diagnostics_backend.diagnostics_app.api.api_v1.api.api_router`
- **Gateway Approach:** Re-import the triage endpoints directly and create a custom router with the "Diagnostics" tag
- **Location:** [gateway/main.py](gateway/main.py#L6-L10)
- **Mount:** `gateway_app.include_router(..., prefix="/diagnostics")`

#### 2. **Mental Health Backend**
- **Original:** Endpoints defined directly on FastAPI app
- **Gateway Approach:** Create a new router and wrap the endpoints with proper tags
- **Location:** [gateway/main.py](gateway/main.py#L13-L114)
- **Mount:** `gateway_app.include_router(mental_health_router)`

#### 3. **Medicine Backend**
- **Original:** Separate routers for medications, reminders, prescriptions
- **Gateway Approach:** Compose them with a prefix router
- **Location:** [gateway/main.py](gateway/main.py#L117-L121)
- **Mount:** `gateway_app.include_router(medicine_router)`

---

## Adding a New Backend

### Example: Adding a Lab Tests Backend

**Step 1:** Create the backend (e.g., `lab_tests_backend/`)

```
lab_tests_backend/
└── lab_tests_app/
    ├── main.py
    └── routes/
        └── tests.py  (with router or app)
```

**Step 2:** Update `gateway/main.py` (add 5 lines)

```python
# At the top of gateway/main.py, add the import
from lab_tests_backend.lab_tests_app.routes import tests as lab_router

# In the "INCLUDE ROUTERS" section, add:
gateway_app.include_router(
    lab_router.router,
    prefix="/lab-tests",
    tags=["Lab Tests"]
)
```

**That's it!** The Swagger UI will auto-update with all new endpoints.

---

## Troubleshooting

### Issue: Module not found error

**Problem:**
```
ModuleNotFoundError: No module named 'diagnostics_backend'
```

**Solution:**
Make sure you're running from the correct directory:
```bash
cd c:\Honey\Projects\My_Sehat\BACKEND
```

The `BACKEND` folder is the workspace root.

### Issue: Port already in use

**Problem:**
```
OSError: [Errno 48] Address already in use
```

**Solution:**
Use a different port:
```bash
uvicorn gateway.main:gateway_app --reload --port 8001
```

### Issue: Endpoints not appearing in Swagger

**Cause:** Router not included properly

**Solution:** Verify in gateway/main.py that `include_router()` is called for all backends.

---

## Testing

### Validate Routes
```bash
python gateway/test_routes.py
```

**Output:** Lists all endpoints grouped by tag

### Validate Startup
```bash
python gateway/test_startup.py
```

**Output:** Confirms all key endpoints are loaded

---

## Key Design Decisions

### ✅ Why `include_router()` and not `mount()`?

- **include_router()**: Merges routes into the main app → Single Swagger UI, single OpenAPI schema
- **mount()**: Creates a sub-application → Separate Swagger UI, separate schemas

**Decision:** Use `include_router()` for true composition.

### ✅ Why separate tags for Medicine?

The medicine backend has three logical groups:
- **Medications**: CRUD operations on medications
- **Reminders**: Dose event generation and tracking
- **Prescriptions**: Prescription upload and management

These tags provide **semantic clarity** in Swagger UI while still being under `/medicine-reminder/*` prefix.

### ✅ Why startup event for mental health?

```python
@gateway_app.on_event("startup")
def on_startup():
    db.init_db()
```

This ensures the mental health database is initialized when the gateway starts (not each backend separately).

---

## Performance & Scalability

### Request Flow
```
Client Request
    ↓
Gateway (FastAPI)
    ↓
Route Handler (tag + path)
    ↓
Backend Service
    ↓
Response (via gateway)
```

**Latency:** Minimal (~<1ms overhead for routing)

### Scaling Strategy

1. **Single Gateway Instance** (current):
   - Suitable for development and small deployments
   - One server process

2. **Horizontal Scaling** (future):
   - Run multiple gateway instances behind a load balancer
   - Each instance independently composes all backends
   - Shared database connections (configured per backend)

---

## Production Checklist

- [ ] Update CORS origins (currently `["*"]`)
- [ ] Enable HTTPS
- [ ] Add authentication/authorization middleware
- [ ] Configure logging and monitoring
- [ ] Set up health check monitoring for each backend
- [ ] Configure database connection pooling
- [ ] Add rate limiting
- [ ] Document API versioning strategy

---

## Architecture Decision Record (ADR)

### Decision: Composition via `include_router()`

**Context:**
- Three independent backends must remain untouched
- Need single Swagger UI and single OpenAPI schema
- Must be extensible for new backends

**Options:**
1. **Option A:** Mount each backend as a sub-application (`mount()`)
   - ❌ Results in separate Swagger UIs
   - ❌ Complex client-side routing

2. **Option B:** Composition via `include_router()` ✅ **CHOSEN**
   - ✅ Single Swagger UI
   - ✅ Unified OpenAPI schema
   - ✅ Clean composition pattern
   - ✅ Minimal overhead

3. **Option C:** Proxy gateway (nginx/Kong)
   - ❌ Additional infrastructure
   - ❌ Harder to debug
   - ❌ No unified OpenAPI schema

**Result:** Chose Option B for simplicity and clarity.

---

## File Structure

```
gateway/
├── main.py                 # Gateway application (composition logic)
├── __init__.py             # Package marker
├── requirements.txt        # Dependencies
├── test_startup.py         # Startup validation
├── test_routes.py          # Route discovery and verification
└── README.md               # This file
```

---

## Support & Contributing

For issues or questions about the gateway:

1. **Check the Gateway Logic:** [gateway/main.py](gateway/main.py)
2. **Verify Routes:** Run `python gateway/test_routes.py`
3. **Check Backend Services:** Each backend has its own README in its folder

---

## License

Same as parent project.
