from typing import Dict, Any, List

class VisionService:
    def __init__(self):
        pass

    async def analyze_image(self, image_bytes: bytes) -> Dict[str, Any]:
        """
        STUB: Returns observations based on mock logic.
        Heuristic: Byte length even -> Rash, odd -> Wound.
        """
        is_wound = len(image_bytes) % 2 != 0
        
        if is_wound:
            return {
                "body_part": "leg",
                "observations": ["open wound", "bleeding", "jagged edges"],
                "quality_flags": [],
                "vision_confidence": {
                    "open_wound": 0.92,
                    "bleeding": 0.78
                }
            }
        else:
            return {
                "body_part": "forearm",
                "observations": ["redness", "mild swelling", "papules"],
                "quality_flags": [],
                "vision_confidence": {
                    "redness": 0.88,
                    "swelling": 0.65
                }
            }
