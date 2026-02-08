"""
FHIR Data Mapping Layer
========================

Maps internal MySehat data models to FHIR R4 resources.
Hospitals NEVER see internal schemas - only FHIR-compliant JSON.

Mappings:
- internal_user        → FHIR Patient
- symptom_checker      → FHIR Observation
- diagnosis            → FHIR Condition
- medicine_reminder    → FHIR MedicationRequest
- lab_reports          → FHIR DiagnosticReport
- scanned_documents    → FHIR DocumentReference
- allergies            → FHIR AllergyIntolerance
- emergency_profile    → FHIR Bundle
"""

from datetime import datetime, date
from typing import Optional, List, Dict, Any
import json
import uuid

from ..models import (
    FHIRPatient, FHIRObservation, FHIRCondition,
    FHIRMedicationRequest, FHIRDiagnosticReport, FHIRDocumentReference,
    FHIRAllergyIntolerance, FHIRBundle, FHIREncounter,
    Identifier, HumanName, ContactPoint, Address, Reference,
    CodeableConcept, Coding, Period, Quantity, Attachment, Annotation,
    BundleEntry, BundleType, Meta, Dosage, AllergyIntoleranceReaction,
    ObservationReferenceRange, DocumentReferenceContent
)


def _generate_fhir_id(prefix: str = "") -> str:
    """Generate a FHIR-compliant ID"""
    return f"{prefix}{uuid.uuid4().hex[:12]}"


def _format_datetime(dt: Optional[datetime]) -> Optional[str]:
    """Format datetime to FHIR format"""
    if dt is None:
        return None
    return dt.strftime("%Y-%m-%dT%H:%M:%S+05:30")  # IST timezone


def _format_date(d: Optional[date]) -> Optional[str]:
    """Format date to FHIR format"""
    if d is None:
        return None
    if isinstance(d, datetime):
        return d.strftime("%Y-%m-%d")
    return d.strftime("%Y-%m-%d") if hasattr(d, 'strftime') else str(d)


# =============================================================================
# USER → FHIR Patient
# =============================================================================

def map_user_to_fhir_patient(
    user_id: str,
    name: Optional[str] = None,
    age: Optional[int] = None,
    gender: Optional[str] = None,
    blood_group: Optional[str] = None,
    phone: Optional[str] = None,
    email: Optional[str] = None,
    address: Optional[str] = None,
    emergency_contacts: Optional[List[Dict]] = None,
) -> FHIRPatient:
    """
    Map internal user data to FHIR Patient resource.
    
    Hospitals receive standardized FHIR Patient, not internal user schema.
    """
    # Parse name into components
    name_parts = (name or "Unknown Patient").split(" ")
    family_name = name_parts[-1] if name_parts else "Unknown"
    given_names = name_parts[:-1] if len(name_parts) > 1 else [name_parts[0] if name_parts else "Unknown"]
    
    # Calculate birth date from age
    birth_date = None
    if age:
        current_year = datetime.now().year
        birth_date = f"{current_year - age}-01-01"  # Approximate
    
    # Map gender
    fhir_gender = None
    if gender:
        gender_lower = gender.lower()
        if gender_lower in ["male", "m"]:
            fhir_gender = "male"
        elif gender_lower in ["female", "f"]:
            fhir_gender = "female"
        else:
            fhir_gender = "other"
    
    # Build telecom
    telecom: List[ContactPoint] = []
    if phone:
        telecom.append(ContactPoint(
            system="phone",
            value=phone,
            use="mobile"
        ))
    if email:
        telecom.append(ContactPoint(
            system="email",
            value=email
        ))
    
    # Build address
    addresses: List[Address] = []
    if address:
        addresses.append(Address(
            use="home",
            text=address,
            country="India"
        ))
    
    # Blood group as extension (FHIR standard extension)
    extensions = []
    if blood_group:
        extensions.append({
            "url": "http://hl7.org/fhir/StructureDefinition/patient-bloodGroup",
            "valueCodeableConcept": {
                "coding": [{
                    "system": "http://terminology.hl7.org/CodeSystem/v3-abo-rh",
                    "code": blood_group,
                    "display": blood_group
                }],
                "text": blood_group
            }
        })
    
    # Emergency contacts
    contacts = []
    if emergency_contacts:
        for ec in emergency_contacts:
            contact_name = HumanName(text=ec.get("name", "Emergency Contact"))
            contact_telecom = []
            if ec.get("phone"):
                contact_telecom.append(ContactPoint(
                    system="phone",
                    value=ec["phone"],
                    use="mobile"
                ))
            contacts.append({
                "relationship": [CodeableConcept(
                    coding=[Coding(
                        system="http://terminology.hl7.org/CodeSystem/v2-0131",
                        code="C",
                        display="Emergency Contact"
                    )],
                    text=ec.get("relationship", "Emergency Contact")
                )],
                "name": contact_name,
                "telecom": contact_telecom
            })
    
    return FHIRPatient(
        id=user_id,
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Patient App",
            profile=["http://hl7.org/fhir/StructureDefinition/Patient"]
        ),
        identifier=[
            Identifier(
                use="official",
                system="urn:mysehat:patient-id",
                value=user_id
            )
        ],
        active=True,
        name=[HumanName(
            use="official",
            family=family_name,
            given=given_names,
            text=name or "Unknown Patient"
        )],
        telecom=telecom,
        gender=fhir_gender,
        birthDate=birth_date,
        address=addresses,
        extension=extensions,
        contact=contacts
    )


# =============================================================================
# SYMPTOM CHECKER → FHIR Observation
# =============================================================================

def map_symptom_to_fhir_observation(
    patient_id: str,
    session_id: str,
    symptom_text: str,
    severity: Optional[str] = None,
    duration: Optional[str] = None,
    body_site: Optional[str] = None,
    recorded_at: Optional[datetime] = None,
    triage_result: Optional[Dict] = None,
) -> FHIRObservation:
    """
    Map symptom checker data to FHIR Observation resource.
    
    Symptoms and triage results are clinical observations.
    """
    # Determine interpretation based on severity
    interpretation = []
    if severity:
        severity_lower = severity.lower()
        if severity_lower in ["critical", "severe"]:
            interpretation.append(CodeableConcept(
                coding=[Coding(
                    system="http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation",
                    code="H",
                    display="High"
                )],
                text=f"Severity: {severity}"
            ))
        elif severity_lower == "moderate":
            interpretation.append(CodeableConcept(
                coding=[Coding(
                    system="http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation",
                    code="N",
                    display="Normal"
                )],
                text=f"Severity: {severity}"
            ))
        else:
            interpretation.append(CodeableConcept(
                coding=[Coding(
                    system="http://terminology.hl7.org/CodeSystem/v3-ObservationInterpretation",
                    code="L",
                    display="Low"
                )],
                text=f"Severity: {severity}"
            ))
    
    # Build note with triage result
    notes = []
    if triage_result:
        notes.append(Annotation(
            text=f"Triage Summary: {triage_result.get('summary', 'N/A')}",
            time=_format_datetime(recorded_at or datetime.utcnow())
        ))
        if triage_result.get("possible_causes"):
            causes = ", ".join([c.get("condition", str(c)) for c in triage_result["possible_causes"][:5]])
            notes.append(Annotation(
                text=f"Possible causes: {causes}"
            ))
    
    return FHIRObservation(
        id=session_id or _generate_fhir_id("obs-"),
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Symptom Checker",
            profile=["http://hl7.org/fhir/StructureDefinition/Observation"]
        ),
        identifier=[
            Identifier(
                system="urn:mysehat:symptom-session",
                value=session_id
            )
        ],
        status="final",
        category=[CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/observation-category",
                code="survey",
                display="Survey"
            )],
            text="Symptom Assessment"
        )],
        code=CodeableConcept(
            coding=[Coding(
                system="http://snomed.info/sct",
                code="418799008",
                display="Finding reported by subject or history provider"
            )],
            text="Patient-reported symptoms"
        ),
        subject=Reference(
            reference=f"Patient/{patient_id}",
            type="Patient"
        ),
        effectiveDateTime=_format_datetime(recorded_at or datetime.utcnow()),
        issued=_format_datetime(datetime.utcnow()),
        valueString=symptom_text,
        interpretation=interpretation,
        note=notes,
        bodySite=CodeableConcept(text=body_site) if body_site else None
    )


# =============================================================================
# DIAGNOSIS → FHIR Condition
# =============================================================================

def map_diagnosis_to_fhir_condition(
    patient_id: str,
    diagnosis_id: str,
    diagnosis_text: str,
    diagnosis_code: Optional[str] = None,
    clinical_status: str = "active",
    verification_status: str = "confirmed",
    severity: Optional[str] = None,
    onset_date: Optional[datetime] = None,
    recorded_date: Optional[datetime] = None,
    recorder_name: Optional[str] = None,
    notes: Optional[str] = None,
) -> FHIRCondition:
    """
    Map diagnosis data to FHIR Condition resource.
    
    Diagnoses from health records become FHIR Conditions.
    """
    # Map severity
    severity_code = None
    if severity:
        severity_lower = severity.lower()
        if severity_lower in ["severe", "critical"]:
            severity_code = CodeableConcept(
                coding=[Coding(
                    system="http://snomed.info/sct",
                    code="24484000",
                    display="Severe"
                )],
                text=severity
            )
        elif severity_lower == "moderate":
            severity_code = CodeableConcept(
                coding=[Coding(
                    system="http://snomed.info/sct",
                    code="6736007",
                    display="Moderate"
                )],
                text=severity
            )
        else:
            severity_code = CodeableConcept(
                coding=[Coding(
                    system="http://snomed.info/sct",
                    code="255604002",
                    display="Mild"
                )],
                text=severity
            )
    
    # Build annotations
    annotations = []
    if notes:
        annotations.append(Annotation(text=notes))
    
    return FHIRCondition(
        id=diagnosis_id or _generate_fhir_id("cond-"),
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Health Records",
            profile=["http://hl7.org/fhir/StructureDefinition/Condition"]
        ),
        identifier=[
            Identifier(
                system="urn:mysehat:condition",
                value=diagnosis_id
            )
        ],
        clinicalStatus=CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/condition-clinical",
                code=clinical_status,
                display=clinical_status.capitalize()
            )]
        ),
        verificationStatus=CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/condition-ver-status",
                code=verification_status,
                display=verification_status.capitalize()
            )]
        ),
        category=[CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/condition-category",
                code="encounter-diagnosis",
                display="Encounter Diagnosis"
            )]
        )],
        severity=severity_code,
        code=CodeableConcept(
            coding=[Coding(
                system="http://snomed.info/sct",
                code=diagnosis_code or "unknown",
                display=diagnosis_text
            )] if diagnosis_code else [],
            text=diagnosis_text
        ),
        subject=Reference(
            reference=f"Patient/{patient_id}",
            type="Patient"
        ),
        onsetDateTime=_format_datetime(onset_date) if onset_date else None,
        recordedDate=_format_datetime(recorded_date or datetime.utcnow()),
        note=annotations
    )


# =============================================================================
# MEDICINE REMINDER → FHIR MedicationRequest
# =============================================================================

def map_medication_to_fhir_medication_request(
    patient_id: str,
    medication_id: str,
    medication_name: str,
    dosage: Optional[str] = None,
    frequency: Optional[str] = None,
    form: Optional[str] = None,
    instructions: Optional[str] = None,
    start_date: Optional[date] = None,
    end_date: Optional[date] = None,
    prescriber_name: Optional[str] = None,
    is_active: bool = True,
) -> FHIRMedicationRequest:
    """
    Map medicine reminder data to FHIR MedicationRequest resource.
    
    Medication reminders become prescription orders in FHIR.
    """
    # Build dosage instructions
    dosage_instructions = []
    if dosage or frequency or instructions:
        dosage_text = []
        if dosage:
            dosage_text.append(dosage)
        if frequency:
            dosage_text.append(frequency)
        if instructions:
            dosage_text.append(instructions)
        
        dosage_instructions.append(Dosage(
            text=" - ".join(dosage_text),
            patientInstruction=instructions
        ))
    
    # Validity period
    validity_period = None
    if start_date or end_date:
        validity_period = Period(
            start=_format_date(start_date),
            end=_format_date(end_date)
        )
    
    return FHIRMedicationRequest(
        id=medication_id or _generate_fhir_id("medreq-"),
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Medicine Reminder",
            profile=["http://hl7.org/fhir/StructureDefinition/MedicationRequest"]
        ),
        identifier=[
            Identifier(
                system="urn:mysehat:medication",
                value=medication_id
            )
        ],
        status="active" if is_active else "completed",
        intent="order",
        category=[CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/medicationrequest-category",
                code="outpatient",
                display="Outpatient"
            )]
        )],
        priority="routine",
        medicationCodeableConcept=CodeableConcept(
            coding=[Coding(
                system="http://www.nlm.nih.gov/research/umls/rxnorm",
                display=medication_name
            )],
            text=f"{medication_name} {form or ''}".strip()
        ),
        subject=Reference(
            reference=f"Patient/{patient_id}",
            type="Patient"
        ),
        authoredOn=_format_datetime(datetime.utcnow()),
        requester=Reference(
            display=prescriber_name or "Unknown Prescriber"
        ) if prescriber_name else None,
        dosageInstruction=dosage_instructions,
        dispenseRequest={
            "validityPeriod": validity_period.model_dump() if validity_period else None
        } if validity_period else None
    )


# =============================================================================
# LAB REPORTS → FHIR DiagnosticReport
# =============================================================================

def map_lab_report_to_fhir_diagnostic_report(
    patient_id: str,
    report_id: str,
    report_type: str,
    document_date: Optional[datetime] = None,
    doctor_name: Optional[str] = None,
    hospital_name: Optional[str] = None,
    diagnosis: Optional[str] = None,
    test_results: Optional[List[Dict]] = None,
    confidence_score: float = 0.0,
) -> FHIRDiagnosticReport:
    """
    Map lab report data to FHIR DiagnosticReport resource.
    
    Lab reports with extracted results become DiagnosticReports.
    """
    # Map report type to LOINC code
    report_type_mapping = {
        "lab_report": ("26436-6", "Laboratory studies"),
        "radiology": ("18748-4", "Diagnostic imaging study"),
        "discharge_summary": ("18842-5", "Discharge summary"),
        "prescription": ("57833-6", "Prescription"),
        "other": ("11502-2", "Laboratory report")
    }
    
    loinc_code, loinc_display = report_type_mapping.get(
        report_type.lower(), 
        ("11502-2", "Laboratory report")
    )
    
    # Build conclusion from diagnosis and test results
    conclusion_parts = []
    if diagnosis:
        conclusion_parts.append(f"Diagnosis: {diagnosis}")
    if test_results:
        abnormal_results = [r for r in test_results if r.get("is_abnormal")]
        if abnormal_results:
            conclusion_parts.append(f"Abnormal findings: {len(abnormal_results)}")
    
    return FHIRDiagnosticReport(
        id=report_id or _generate_fhir_id("diag-"),
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Health Records",
            profile=["http://hl7.org/fhir/StructureDefinition/DiagnosticReport"]
        ),
        identifier=[
            Identifier(
                system="urn:mysehat:health-record",
                value=report_id
            )
        ],
        status="final",
        category=[CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/v2-0074",
                code="LAB" if report_type.lower() == "lab_report" else "RAD",
                display="Laboratory" if report_type.lower() == "lab_report" else "Radiology"
            )]
        )],
        code=CodeableConcept(
            coding=[Coding(
                system="http://loinc.org",
                code=loinc_code,
                display=loinc_display
            )],
            text=report_type.replace("_", " ").title()
        ),
        subject=Reference(
            reference=f"Patient/{patient_id}",
            type="Patient"
        ),
        effectiveDateTime=_format_datetime(document_date) if document_date else None,
        issued=_format_datetime(datetime.utcnow()),
        performer=[
            Reference(display=doctor_name) if doctor_name else None,
            Reference(display=hospital_name) if hospital_name else None
        ],
        conclusion="; ".join(conclusion_parts) if conclusion_parts else None
    )


# =============================================================================
# SCANNED DOCUMENTS → FHIR DocumentReference
# =============================================================================

def map_document_to_fhir_document_reference(
    patient_id: str,
    document_id: str,
    document_type: str,
    document_date: Optional[datetime] = None,
    doctor_name: Optional[str] = None,
    hospital_name: Optional[str] = None,
    file_path: Optional[str] = None,
    content_type: str = "application/pdf",
    description: Optional[str] = None,
    raw_text: Optional[str] = None,
) -> FHIRDocumentReference:
    """
    Map scanned document data to FHIR DocumentReference resource.
    
    Uploaded medical documents become DocumentReferences.
    """
    # Map document type to LOINC
    doc_type_mapping = {
        "prescription": ("57833-6", "Prescription for medication"),
        "lab_report": ("11502-2", "Laboratory report"),
        "radiology": ("18748-4", "Diagnostic imaging study"),
        "discharge_summary": ("18842-5", "Discharge summary"),
        "medical_certificate": ("48766-0", "Medical certificate"),
        "other": ("34117-2", "History and physical note")
    }
    
    loinc_code, loinc_display = doc_type_mapping.get(
        document_type.lower(),
        ("34117-2", "History and physical note")
    )
    
    # Build content
    content = []
    if file_path or raw_text:
        content.append(DocumentReferenceContent(
            attachment=Attachment(
                contentType=content_type,
                url=f"file://{file_path}" if file_path else None,
                title=description or f"{document_type} document",
                creation=_format_datetime(document_date) if document_date else None
            )
        ))
    
    return FHIRDocumentReference(
        id=document_id or _generate_fhir_id("doc-"),
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Health Records",
            profile=["http://hl7.org/fhir/StructureDefinition/DocumentReference"]
        ),
        masterIdentifier=Identifier(
            system="urn:mysehat:document",
            value=document_id
        ),
        identifier=[
            Identifier(
                system="urn:mysehat:health-record",
                value=document_id
            )
        ],
        status="current",
        type=CodeableConcept(
            coding=[Coding(
                system="http://loinc.org",
                code=loinc_code,
                display=loinc_display
            )],
            text=document_type.replace("_", " ").title()
        ),
        category=[CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/media-category",
                code="document",
                display="Document"
            )]
        )],
        subject=Reference(
            reference=f"Patient/{patient_id}",
            type="Patient"
        ),
        date=_format_datetime(document_date) if document_date else None,
        author=[
            Reference(display=doctor_name) if doctor_name else None
        ],
        custodian=Reference(display=hospital_name) if hospital_name else None,
        description=description,
        content=content
    )


# =============================================================================
# ALLERGIES → FHIR AllergyIntolerance
# =============================================================================

def map_allergy_to_fhir_allergy_intolerance(
    patient_id: str,
    allergy_id: str,
    allergy_name: str,
    severity: Optional[str] = None,
    clinical_status: str = "active",
    verification_status: str = "confirmed",
    recorded_date: Optional[datetime] = None,
) -> FHIRAllergyIntolerance:
    """
    Map allergy data to FHIR AllergyIntolerance resource.
    """
    # Map severity to FHIR criticality
    criticality = None
    reaction_severity = None
    if severity:
        severity_lower = severity.lower()
        if severity_lower == "severe":
            criticality = "high"
            reaction_severity = "severe"
        elif severity_lower == "moderate":
            criticality = "low"
            reaction_severity = "moderate"
        else:
            criticality = "low"
            reaction_severity = "mild"
    
    return FHIRAllergyIntolerance(
        id=allergy_id or _generate_fhir_id("allergy-"),
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Health Records",
            profile=["http://hl7.org/fhir/StructureDefinition/AllergyIntolerance"]
        ),
        identifier=[
            Identifier(
                system="urn:mysehat:allergy",
                value=allergy_id
            )
        ],
        clinicalStatus=CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/allergyintolerance-clinical",
                code=clinical_status,
                display=clinical_status.capitalize()
            )]
        ),
        verificationStatus=CodeableConcept(
            coding=[Coding(
                system="http://terminology.hl7.org/CodeSystem/allergyintolerance-verification",
                code=verification_status,
                display=verification_status.capitalize()
            )]
        ),
        type="allergy",
        category=["medication"],  # Most common, can be updated
        criticality=criticality,
        code=CodeableConcept(
            text=allergy_name
        ),
        patient=Reference(
            reference=f"Patient/{patient_id}",
            type="Patient"
        ),
        recordedDate=_format_datetime(recorded_date or datetime.utcnow()),
        reaction=[AllergyIntoleranceReaction(
            severity=reaction_severity,
            manifestation=[CodeableConcept(text="Allergic reaction")]
        )] if reaction_severity else []
    )


# =============================================================================
# EMERGENCY PROFILE → FHIR Bundle
# =============================================================================

def map_emergency_profile_to_fhir_bundle(
    patient_id: str,
    name: Optional[str] = None,
    age: Optional[int] = None,
    gender: Optional[str] = None,
    blood_group: Optional[str] = None,
    allergies: Optional[List[str]] = None,
    chronic_conditions: Optional[List[str]] = None,
    current_medications: Optional[List[str]] = None,
    emergency_contacts: Optional[List[Dict]] = None,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    sos_event_id: Optional[str] = None,
    consent_expires_at: Optional[datetime] = None,
) -> FHIRBundle:
    """
    Map emergency profile to FHIR Bundle resource.
    
    Contains Patient, AllergyIntolerances, Conditions, and MedicationRequests.
    Auto-expires after SOS ends.
    """
    bundle_id = sos_event_id or _generate_fhir_id("sos-bundle-")
    entries: List[BundleEntry] = []
    
    # 1. Patient resource
    patient = map_user_to_fhir_patient(
        user_id=patient_id,
        name=name,
        age=age,
        gender=gender,
        blood_group=blood_group,
        emergency_contacts=emergency_contacts
    )
    
    # Add location extension for emergency
    if latitude and longitude:
        patient.extension.append({
            "url": "http://hl7.org/fhir/StructureDefinition/geolocation",
            "extension": [
                {"url": "latitude", "valueDecimal": latitude},
                {"url": "longitude", "valueDecimal": longitude}
            ]
        })
    
    entries.append(BundleEntry(
        fullUrl=f"urn:uuid:patient-{patient_id}",
        resource=patient.model_dump(by_alias=True, exclude_none=True)
    ))
    
    # 2. Allergy resources
    if allergies:
        for idx, allergy in enumerate(allergies):
            allergy_resource = map_allergy_to_fhir_allergy_intolerance(
                patient_id=patient_id,
                allergy_id=f"allergy-{patient_id}-{idx}",
                allergy_name=allergy,
                severity="moderate",  # Default for emergency
                clinical_status="active"
            )
            entries.append(BundleEntry(
                fullUrl=f"urn:uuid:allergy-{patient_id}-{idx}",
                resource=allergy_resource.model_dump(by_alias=True, exclude_none=True)
            ))
    
    # 3. Chronic conditions
    if chronic_conditions:
        for idx, condition in enumerate(chronic_conditions):
            condition_resource = map_diagnosis_to_fhir_condition(
                patient_id=patient_id,
                diagnosis_id=f"condition-{patient_id}-{idx}",
                diagnosis_text=condition,
                clinical_status="active",
                verification_status="confirmed"
            )
            entries.append(BundleEntry(
                fullUrl=f"urn:uuid:condition-{patient_id}-{idx}",
                resource=condition_resource.model_dump(by_alias=True, exclude_none=True)
            ))
    
    # 4. Current medications
    if current_medications:
        for idx, medication in enumerate(current_medications):
            med_resource = map_medication_to_fhir_medication_request(
                patient_id=patient_id,
                medication_id=f"medication-{patient_id}-{idx}",
                medication_name=medication,
                is_active=True
            )
            entries.append(BundleEntry(
                fullUrl=f"urn:uuid:medication-{patient_id}-{idx}",
                resource=med_resource.model_dump(by_alias=True, exclude_none=True)
            ))
    
    # Add DPDP consent expiry metadata
    meta_tags = [
        Coding(
            system="urn:mysehat:dpdp",
            code="emergency-access",
            display="Emergency Access under DPDP Act 2023"
        )
    ]
    if consent_expires_at:
        meta_tags.append(Coding(
            system="urn:mysehat:consent-expiry",
            code="auto-expire",
            display=f"Expires: {_format_datetime(consent_expires_at)}"
        ))
    
    return FHIRBundle(
        id=bundle_id,
        meta=Meta(
            lastUpdated=_format_datetime(datetime.utcnow()),
            source="MySehat Emergency SOS",
            tag=meta_tags
        ),
        identifier=Identifier(
            system="urn:mysehat:sos-bundle",
            value=bundle_id
        ),
        type=BundleType.COLLECTION,
        timestamp=_format_datetime(datetime.utcnow()),
        total=len(entries),
        entry=entries
    )
