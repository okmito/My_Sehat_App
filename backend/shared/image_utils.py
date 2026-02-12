import io
from PIL import Image
from fastapi import UploadFile, HTTPException
import gc

# Constants for memory optimization
MAX_IMAGE_WIDTH = 1200
JPEG_QUALITY = 70
MAX_FILE_SIZE_MB = 5
MAX_FILE_SIZE_BYTES = MAX_FILE_SIZE_MB * 1024 * 1024

def process_image_upload(file_obj: io.BytesIO) -> bytes:
    """
    Process an uploaded image to reduce memory footprint.
    - Resizes to max width 1200px
    - Converts to JPEG with 70% quality
    - Returns bytes of optimized image
    
    Args:
        file_obj: BytesIO object containing the image data
        
    Returns:
        bytes: Optimized image data
    """
    try:
        with Image.open(file_obj) as img:
            # Convert to RGB if necessary (e.g. for PNG with alpha)
            if img.mode in ('RGBA', 'P'):
                img = img.convert('RGB')
            
            # Resize if too large
            if img.width > MAX_IMAGE_WIDTH:
                aspect_ratio = img.height / img.width
                new_height = int(MAX_IMAGE_WIDTH * aspect_ratio)
                img = img.resize((MAX_IMAGE_WIDTH, new_height), Image.Resampling.LANCZOS)
            
            # Save to bytes
            output = io.BytesIO()
            img.save(output, format='JPEG', quality=JPEG_QUALITY, optimize=True)
            optimized_bytes = output.getvalue()
            
            # Explicit cleanup
            output.close()
            
            return optimized_bytes
            
    except Exception as e:
        print(f"Error processing image: {e}")
        raise HTTPException(status_code=400, detail="Invalid image file")
    finally:
        # Force garbage collection
        gc.collect()

async def validate_and_read_upload(file: UploadFile) -> bytes:
    """
    Validate and read an uploaded file, enforcing size limits.
    """
    # Check content type
    if file.content_type not in ['image/jpeg', 'image/png', 'image/jpg', 'image/webp']:
         raise HTTPException(status_code=400, detail="Invalid file type. Allowed: JPEG, PNG, WEBP")
         
    # Read file content safely
    # Note: SpooledTemporaryFile in UploadFile already handles memory management for large files
    # by spilling to disk. We just need to read it.
    content = await file.read()
    
    if len(content) > MAX_FILE_SIZE_BYTES:
         raise HTTPException(status_code=400, detail=f"File size exceeds {MAX_FILE_SIZE_MB}MB limit")
         
    return content
