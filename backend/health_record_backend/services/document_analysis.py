"""
Document Analysis Service using GROQ LLM
Extracts structured medical information from documents
"""
import base64
import json
import re
import io
from typing import Optional, Tuple
from datetime import datetime
import httpx

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core.config import settings
from models.schemas import (
    DocumentAnalysisResponse, 
    MedicationBase, 
    TestResultBase,
    CriticalInfoBase,
    CriticalInfoType
)

# Try to import PDF libraries
try:
    import pypdf
    PDF_SUPPORT = True
except ImportError:
    try:
        import PyPDF2 as pypdf
        PDF_SUPPORT = True
    except ImportError:
        PDF_SUPPORT = False

# Try to import OCR for scanned PDFs
try:
    import pytesseract
    from pdf2image import convert_from_bytes
    OCR_SUPPORT = True
except ImportError:
    OCR_SUPPORT = False


class DocumentAnalysisService:
    """Service for analyzing medical documents using GROQ LLM"""
    
    def __init__(self):
        self.api_key = settings.GROQ_API_KEY
        self.model = settings.GROQ_MODEL
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"
    
    def extract_text_from_pdf(self, pdf_bytes: bytes) -> Tuple[str, bool]:
        """
        Extract text from PDF file.
        Returns tuple of (extracted_text, is_scanned_pdf)
        """
        if not PDF_SUPPORT:
            raise ImportError("PDF support requires pypdf or PyPDF2. Install with: pip install pypdf")
        
        extracted_text = ""
        is_scanned = False
        
        try:
            # Try to extract text directly from PDF
            pdf_reader = pypdf.PdfReader(io.BytesIO(pdf_bytes))
            
            # LIMIT: Process max 3 pages to save memory
            max_pages = min(len(pdf_reader.pages), 3)
            
            for i in range(max_pages):
                page = pdf_reader.pages[i]
                page_text = page.extract_text()
                if page_text:
                    extracted_text += page_text + "\n\n"
            
            # If no text extracted, it might be a scanned PDF
            if not extracted_text.strip():
                is_scanned = True
                if OCR_SUPPORT:
                    # Convert PDF pages to images and OCR
                    # LIMIT: Process max 2 pages for OCR (it's heavy)
                    images = convert_from_bytes(pdf_bytes, first_page=1, last_page=2)
                    for i, image in enumerate(images):
                        page_text = pytesseract.image_to_string(image)
                        extracted_text += f"--- Page {i+1} ---\n{page_text}\n\n"
                        
                    # Cleanup images
                    del images
                else:
                    extracted_text = "[PDF contains scanned images. OCR not available. Install pytesseract and pdf2image for OCR support.]"
            
            # Force cleanup
            del pdf_reader
            import gc
            gc.collect()
            
            return extracted_text.strip(), is_scanned
            
        except Exception as e:
            raise Exception(f"Failed to extract text from PDF: {str(e)}")
    
    async def analyze_pdf(self, pdf_bytes: bytes) -> DocumentAnalysisResponse:
        """
        Analyze a PDF medical document and extract structured information
        """
        # Extract text from PDF
        extracted_text, is_scanned = self.extract_text_from_pdf(pdf_bytes)
        
        if not extracted_text or extracted_text.startswith("[PDF contains scanned"):
            # If PDF is scanned and no OCR, try to convert first page to image for vision analysis
            if OCR_SUPPORT:
                try:
                    images = convert_from_bytes(pdf_bytes, first_page=1, last_page=1)
                    if images:
                        # Convert first page to base64 and use vision model
                        img_byte_arr = io.BytesIO()
                        images[0].save(img_byte_arr, format='PNG')
                        img_base64 = base64.b64encode(img_byte_arr.getvalue()).decode()
                        return await self.analyze_document(img_base64, "png")
                except Exception:
                    pass
            
            return DocumentAnalysisResponse(
                document_type="other",
                overall_confidence=0.0,
                notes="PDF appears to be scanned/image-based and OCR is not available. Please upload as image instead.",
                ai_disclaimer="This information is extracted from uploaded documents. It is not a medical diagnosis and should be verified by a professional."
            )
        
        # Analyze the extracted text using text model
        return await self.analyze_text(extracted_text)
    
    async def analyze_document(self, image_base64: str, file_type: str = "image") -> DocumentAnalysisResponse:
        """
        Analyze a medical document image/PDF and extract structured information
        """
        if not self.api_key:
            raise ValueError("GROQ_API_KEY not configured. Please set the GROQ_API_KEY environment variable.")
        
        # Build the analysis prompt
        system_prompt = self._build_system_prompt()
        user_prompt = self._build_user_prompt()
        
        # For image analysis, we use vision-capable model
        # Try different vision models in order of preference
        vision_models = [
            "llama-3.2-11b-vision-preview",  # Smaller but more available
            "llama-3.2-90b-vision-preview",  # Larger model
        ]
        
        messages = [
            {"role": "system", "content": system_prompt},
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": user_prompt},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/{file_type};base64,{image_base64}"
                        }
                    }
                ]
            }
        ]
        
        last_error = None
        async with httpx.AsyncClient(timeout=120.0) as client:
            for model in vision_models:
                try:
                    response = await client.post(
                        self.api_url,
                        headers={
                            "Authorization": f"Bearer {self.api_key}",
                            "Content-Type": "application/json"
                        },
                        json={
                            "model": model,
                            "messages": messages,
                            "temperature": 0.1,
                            "max_tokens": 4096
                        }
                    )
                    
                    if response.status_code == 200:
                        result = response.json()
                        content = result["choices"][0]["message"]["content"]
                        return self._parse_analysis_response(content)
                    else:
                        last_error = f"Model {model}: {response.status_code} - {response.text}"
                        continue
                except Exception as e:
                    last_error = f"Model {model}: {str(e)}"
                    continue
            
            # If all vision models fail, return a helpful error
            raise Exception(f"GROQ Vision API error. Last error: {last_error}")
    
    async def analyze_text(self, ocr_text: str) -> DocumentAnalysisResponse:
        """
        Analyze OCR-extracted text from a medical document
        """
        if not self.api_key:
            raise ValueError("GROQ_API_KEY not configured")
        
        system_prompt = self._build_system_prompt()
        user_prompt = f"""Analyze the following medical document text and extract structured information:

--- DOCUMENT TEXT ---
{ocr_text}
--- END DOCUMENT ---

{self._build_extraction_instructions()}"""
        
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                self.api_url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json"
                },
                json={
                    "model": self.model,
                    "messages": [
                        {"role": "system", "content": system_prompt},
                        {"role": "user", "content": user_prompt}
                    ],
                    "temperature": 0.1,
                    "max_tokens": 4096
                }
            )
            
            if response.status_code != 200:
                raise Exception(f"GROQ API error: {response.text}")
            
            result = response.json()
            content = result["choices"][0]["message"]["content"]
            
            return self._parse_analysis_response(content)
    
    def _build_system_prompt(self) -> str:
        return """You are a secure medical document analysis assistant integrated into a DPDP-compliant health platform.

Your task is to analyze medical documents and extract structured medical information accurately while preserving medical context and terminology.

CRITICAL RULES:
1. Do NOT infer diagnoses beyond what is EXPLICITLY stated in the document
2. Do NOT provide medical advice
3. Only extract information that is clearly visible/stated
4. Assign confidence scores based on clarity of text/data
5. Flag any ambiguous or unclear fields
6. Normalize medical abbreviations (e.g., BP → Blood Pressure, Rx → Prescription)

You must respond ONLY with valid JSON in the specified format."""
    
    def _build_user_prompt(self) -> str:
        return f"""Analyze this medical document image and extract all relevant medical information.

{self._build_extraction_instructions()}"""
    
    def _build_extraction_instructions(self) -> str:
        return """Extract and return a JSON object with this EXACT structure:

{
    "document_type": "prescription|lab_report|radiology|discharge_summary|medical_certificate|other",
    "date": "YYYY-MM-DD or null if not found",
    "doctor": "Doctor name or null",
    "hospital": "Hospital/Clinic name or null",
    "patient_name": "Patient name or null",
    "diagnosis": "ONLY if explicitly written, otherwise null",
    "medications": [
        {
            "name": "Medication name",
            "dosage": "e.g., 500mg",
            "frequency": "e.g., Twice daily",
            "duration": "e.g., 5 days",
            "instructions": "e.g., Take after meals",
            "confidence": 0.0-1.0
        }
    ],
    "test_results": [
        {
            "test_name": "Test name",
            "result_value": "Value",
            "unit": "Unit of measurement",
            "reference_range": "Normal range",
            "is_abnormal": true/false,
            "confidence": 0.0-1.0
        }
    ],
    "notes": "Any clinical notes or remarks",
    "critical_info": [
        {
            "info_type": "blood_group|allergy|chronic_condition",
            "value": "The value",
            "severity": "mild|moderate|severe (for allergies)"
        }
    ],
    "overall_confidence": 0.0-1.0,
    "low_confidence_fields": ["list of field names with confidence < 0.7"]
}

IMPORTANT: Respond ONLY with the JSON object, no additional text."""
    
    def _parse_analysis_response(self, content: str) -> DocumentAnalysisResponse:
        """Parse the LLM response into structured data"""
        try:
            # Try to extract JSON from the response
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                data = json.loads(json_match.group())
            else:
                data = json.loads(content)
            
            # Parse medications
            medications = []
            for med in data.get("medications", []):
                medications.append(MedicationBase(
                    name=med.get("name", "Unknown"),
                    dosage=med.get("dosage"),
                    frequency=med.get("frequency"),
                    duration=med.get("duration"),
                    instructions=med.get("instructions"),
                    confidence=float(med.get("confidence", 0.5))
                ))
            
            # Parse test results
            test_results = []
            for test in data.get("test_results", []):
                test_results.append(TestResultBase(
                    test_name=test.get("test_name", "Unknown"),
                    result_value=test.get("result_value"),
                    unit=test.get("unit"),
                    reference_range=test.get("reference_range"),
                    is_abnormal=test.get("is_abnormal", False),
                    confidence=float(test.get("confidence", 0.5))
                ))
            
            # Parse critical info
            critical_info = []
            for info in data.get("critical_info", []):
                info_type_str = info.get("info_type", "chronic_condition")
                try:
                    info_type = CriticalInfoType(info_type_str)
                except ValueError:
                    info_type = CriticalInfoType.CHRONIC_CONDITION
                
                critical_info.append(CriticalInfoBase(
                    info_type=info_type,
                    value=info.get("value", ""),
                    severity=info.get("severity"),
                    share_in_emergency=True
                ))
            
            return DocumentAnalysisResponse(
                document_type=data.get("document_type", "other"),
                date=data.get("date"),
                doctor=data.get("doctor"),
                hospital=data.get("hospital"),
                patient_name=data.get("patient_name"),
                diagnosis=data.get("diagnosis"),
                medications=medications,
                test_results=test_results,
                notes=data.get("notes"),
                critical_info=critical_info,
                overall_confidence=float(data.get("overall_confidence", 0.5)),
                purpose_tag="Personal Health Record",
                storage_policy="Encrypted | User-owned | DPDP-compliant",
                ai_disclaimer="This information is extracted from uploaded documents. It is not a medical diagnosis and should be verified by a professional."
            )
            
        except json.JSONDecodeError as e:
            # Return a default response if parsing fails
            return DocumentAnalysisResponse(
                document_type="other",
                overall_confidence=0.0,
                notes=f"Failed to parse document. Raw text: {content[:500]}",
                ai_disclaimer="This information is extracted from uploaded documents. It is not a medical diagnosis and should be verified by a professional."
            )


# Singleton instance
document_analysis_service = DocumentAnalysisService()
