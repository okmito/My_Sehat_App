# DPDP Act 2023 Compliance Implementation

## MySehat Platform - Privacy by Design Architecture

**"MySehat is not just privacy-aware — it is DPDP-native, where legal compliance, ethical AI, and user data ownership are enforced directly at the system architecture level."**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Core DPDP Modules](#core-dpdp-modules)
3. [Service-Specific Compliance](#service-specific-compliance)
4. [User Rights Endpoints](#user-rights-endpoints)
5. [AI Governance](#ai-governance)
6. [Emergency Data Handling](#emergency-data-handling)
7. [Audit Trail](#audit-trail)

---

## 🎯 Overview

This implementation enforces Digital Personal Data Protection Act, 2023 compliance across all 5 microservices of the MySehat healthcare platform.

### Key Principles Implemented

| DPDP Principle | Implementation |
|----------------|----------------|
| **Consent-based Processing** | All data access requires valid consent via ConsentEngine |
| **Purpose Limitation** | Each consent is purpose-bound (treatment, storage, AI processing, etc.) |
| **Data Minimization** | Emergency access provides only life-critical data |
| **Right to Access** | `GET /my-data/{user_id}` on all services |
| **Right to Erasure** | `DELETE /my-data/{user_id}?confirm=true` on all services |
| **Right to Correction** | PATCH endpoints available for data updates |
| **AI Transparency** | Clear disclaimers on all AI-generated outputs |
| **Audit Trail** | Complete logging of all data access |

---

## 🔧 Core DPDP Modules

Located in: `backend/shared/dpdp/`

### 1. Consent Engine (`consent.py`)

```python
from shared.dpdp import ConsentEngine, ConsentCheck, DataCategory, Purpose

# Check consent before data access
result = consent_engine.check_consent(ConsentCheck(
    user_id="user123",
    data_category=DataCategory.MENTAL_HEALTH,
    purpose=Purpose.AI_PROCESSING,
    granted_to=GrantedTo.AI_SERVICE
))

if not result.is_valid:
    raise HTTPException(403, "Consent required")
```

**Data Categories:**
- `LOCATION` - GPS coordinates
- `MENTAL_HEALTH` - Chat sessions, mood data (STRICTEST)
- `DOCUMENTS` - Uploaded health records
- `MEDICATIONS` - Prescriptions, reminders
- `DIAGNOSTICS` - Symptom checker sessions
- `EMERGENCY` - SOS events
- `HEALTH_RECORDS` - Extracted medical data
- `PERSONAL_INFO` - Name, age, contacts

**Purposes:**
- `EMERGENCY` - Life-critical access
- `TREATMENT` - Medical care
- `STORAGE` - Data retention
- `AI_PROCESSING` - AI analysis
- `REMINDER` - Notifications
- `ANALYTICS` - Health insights
- `SHARING` - Third-party access

### 2. Audit Logger (`audit.py`)

```python
from shared.dpdp import AuditLogger, AuditAction

audit_logger = get_audit_logger("service_name")

# Log data access
audit_logger.log_data_access(
    user_id="user123",
    action=AuditAction.READ,
    resource_type="health_record",
    resource_id="record_456",
    purpose="user_view"
)

# Log AI processing
audit_logger.log_ai_processing(
    user_id="user123",
    model_used="llama-3.3-70b-versatile",
    input_type="text",
    consent_id=consent_id,
    purpose="symptom_analysis"
)

# Log denied access
audit_logger.log_access_denied(
    user_id="user123",
    resource_type="mental_health",
    reason="Consent not granted"
)
```

### 3. User Rights Manager (`user_rights.py`)

```python
from shared.dpdp import UserRightsManager

rights_manager = get_user_rights_manager()

# Request data erasure (7-day grace period)
rights_manager.request_erasure(user_id, reason="User requested")

# Export user data
data = rights_manager.export_user_data(user_id, services=["all"])

# Request correction
rights_manager.request_correction(user_id, field, old_value, new_value)
```

### 4. AI Governance (`ai_governance.py`)

```python
from shared.dpdp import AIGovernance, AIFeature, DISCLAIMERS

ai_gov = get_ai_governance("service_name")

# Check AI consent
is_valid, consent_id, error = ai_gov.check_ai_consent(user_id, AIFeature.SYMPTOM_CHECKER)

# Get disclaimer
disclaimer = ai_gov.get_disclaimer(AIFeature.SYMPTOM_CHECKER)

# User opt-out
ai_gov.opt_out(user_id, AIFeature.MENTAL_HEALTH_CHAT)
```

### 5. Emergency Data (`emergency_data.py`)

```python
from shared.dpdp import EmergencyDataPacket, get_emergency_data_packet

# Build minimal emergency packet based on user config
packet = get_emergency_data_packet(
    user_id=user_id,
    config=user_emergency_config,  # User controls what's shared
    user_profile=profile_data,
    location=(lat, lon),
    consent_id=emergency_consent_id,
    expires_at=expiry_time  # Auto-revoke after emergency
)
```

---

## 🏥 Service-Specific Compliance

### SOS Emergency (Port 8000)

| Feature | DPDP Implementation |
|---------|---------------------|
| Emergency Consent | Auto-granted, time-limited (24h) |
| Data Shared | ONLY: blood group, allergies, chronic conditions, current meds, location |
| Data Blocked | Mental health notes, full medical history, financial data |
| Auto-Revoke | Consent revoked when emergency status = RESOLVED |

**New Endpoints:**
- `GET /emergency-profile/{user_id}` - User's emergency data config
- `PUT /emergency-profile/{user_id}` - Update sharing preferences
- `GET /sos/{sos_id}/emergency-data` - Minimal data for responders
- `DELETE /sos/user/{user_id}/history` - Right to Erasure

### Symptom Checker (Port 8001)

| Feature | DPDP Implementation |
|---------|---------------------|
| AI Disclaimer | Displayed on every response |
| Consent Check | Optional (anonymous sessions allowed) |
| Session Delete | `DELETE /triage/session/{id}` |
| Audit Logging | All AI queries logged |

**AI Disclaimer:**
```
⚠️ AI Assistance Disclaimer: This is an AI-powered symptom checker that provides 
general health information only. It is NOT a medical diagnosis. Always consult 
a qualified healthcare professional for proper diagnosis and treatment.
```

### Medicine Reminder (Port 8002)

| Feature | DPDP Implementation |
|---------|---------------------|
| Data Export | `GET /my-data/` |
| Data Delete | `DELETE /my-data/?confirm=true` |
| Emergency Summary | `GET /my-data/emergency-summary` (current meds only) |

### Mental Health (Port 8003) - STRICTEST

| Feature | DPDP Implementation |
|---------|---------------------|
| Anonymous Storage | User ID hashed with service-specific salt |
| External Block | SOS, hospitals CANNOT access this data |
| Session-Only Mode | `session_only=true` skips storage entirely |
| Consent Required | EXPLICIT opt-in before any chat |
| AI Opt-Out | User can disable AI processing |

**Privacy Header:**
```python
X-Calling-Service: blocked_services = ["sos_backend", "hospital_service", "ambulance_service"]
```

**Endpoints:**
- `POST /consent/grant` - Explicit consent with storage preferences
- `POST /consent/revoke` - Immediately stops processing
- `GET /my-data/{user_id}` - Export all data
- `DELETE /my-data/{user_id}?confirm=true` - Right to Erasure

### Health Records (Port 8004)

| Feature | DPDP Implementation |
|---------|---------------------|
| Storage Options | Permanent, Temporary (auto-delete), View-only |
| Emergency Toggle | Per-record emergency sharing control |
| AI Disclaimer | On all extracted data |
| Consent Logging | `ConsentLog` table tracks all access |

**Storage Types:**
```python
class StorageType(str, Enum):
    PERMANENT = "permanent"      # Stored until user deletes
    TEMPORARY = "temporary"      # Auto-delete after 30 days
    VIEW_ONLY = "view_only"      # Never stored
```

---

## 🔐 User Rights Endpoints

### Standard Endpoints (All Services)

```
GET    /my-data/{user_id}              # Right to Access (data export)
DELETE /my-data/{user_id}?confirm=true # Right to Erasure
PATCH  /my-data/{user_id}              # Right to Correction
GET    /my-data/{user_id}/audit-trail  # Transparency (who accessed)
```

### Response Format

```json
{
    "user_id": "user123",
    "export_date": "2025-01-15T10:30:00Z",
    "records": [...],
    "dpdp_notice": "This is your complete data as per DPDP Act 2023 Right to Access."
}
```

---

## 🤖 AI Governance

### Disclaimers by Feature

| Feature | Disclaimer |
|---------|------------|
| Symptom Checker | "AI-powered, NOT medical diagnosis" |
| Mental Health Chat | "AI companion, NOT therapist" |
| Document Analysis | "AI-extracted, verify with healthcare provider" |
| Health Insights | "Informational only, not medical advice" |
| Medication Interaction | "Verify with pharmacist/doctor" |

### AI Opt-Out

Users can disable AI features per-service:

```python
# Opt out of symptom checker AI
ai_governance.opt_out(user_id, AIFeature.SYMPTOM_CHECKER)

# Check preferences
prefs = ai_governance.get_user_ai_preferences(user_id)
# Returns: {"symptom_checker": False, "mental_health_chat": True, ...}
```

---

## 🚨 Emergency Data Handling

### What Emergency Responders CAN Access

✅ Blood group
✅ Known allergies  
✅ Chronic conditions
✅ Current medications (names + dosages)
✅ Emergency contacts
✅ Current location
✅ Name and age (optional)

### What Emergency Responders CANNOT Access

❌ Mental health notes/sessions
❌ Full medical history
❌ Diagnostic history
❌ Personal documents
❌ Financial/insurance details
❌ AI conversation logs

### User Control

Users configure what's shared via Emergency Profile:

```python
{
    "share_blood_group": true,
    "share_allergies": true,
    "share_chronic_conditions": true,
    "share_current_medications": true,
    "share_emergency_contacts": true,
    "share_name": true,
    "share_age": true,
    "share_organ_donor_status": false,  # Opt-in
    "share_insurance_info": false,       # Opt-in
    "require_manual_confirmation": false
}
```

---

## 📊 Audit Trail

Every data access is logged with:

- **Who**: User ID and service making request
- **What**: Resource type and ID
- **When**: Timestamp
- **Why**: Purpose of access
- **Consent**: Reference to consent record
- **Action**: READ, WRITE, UPDATE, DELETE, AI_PROCESS, etc.

### Audit Actions

```python
class AuditAction(str, Enum):
    READ = "read"
    WRITE = "write"
    UPDATE = "update"
    DELETE = "delete"
    CONSENT_GRANTED = "consent_granted"
    CONSENT_REVOKED = "consent_revoked"
    AI_PROCESSING = "ai_processing"
    EMERGENCY_ACCESS = "emergency_access"
    EMERGENCY_END = "emergency_end"
    DATA_EXPORT = "data_export"
    DATA_ERASURE = "data_erasure"
    DATA_CORRECTION = "data_correction"
    ACCESS_DENIED = "access_denied"
```

---

## ✅ Compliance Checklist

| Requirement | Status | Implementation |
|-------------|--------|----------------|
| Consent before processing | ✅ | ConsentEngine.check_consent() |
| Purpose limitation | ✅ | Purpose enum in consent |
| Data minimization | ✅ | EmergencyDataPacket whitelist |
| Right to access | ✅ | GET /my-data endpoints |
| Right to erasure | ✅ | DELETE /my-data endpoints |
| Right to correction | ✅ | PATCH endpoints |
| AI transparency | ✅ | Disclaimers on all AI output |
| Audit trail | ✅ | AuditLogger on all services |
| Emergency access controls | ✅ | Time-limited, minimal data |
| Mental health protection | ✅ | Strictest mode, no external access |

---

## 🔄 Future Enhancements

1. **Encryption at rest** - Add AES-256 for stored sensitive data
2. **Data retention policies** - Auto-delete based on data type
3. **Consent renewal** - Periodic re-consent for long-term storage
4. **Breach notification** - Automated alerting system
5. **Cross-border transfer** - Compliance with international transfers

---

*Last Updated: January 2025*
*Compliance Version: DPDP Act 2023 v1.0*
