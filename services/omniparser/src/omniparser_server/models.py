from pydantic import BaseModel, Field
from typing import List, Optional

class ParseRequest(BaseModel):
    image: str = Field(..., description="Base64 encoded screenshot image string")
    format: str = Field("structured", description="Output format, default is 'structured'")

class UIElement(BaseModel):
    bbox: List[float] = Field(..., description="Bounding box [x1, y1, x2, y2]")
    type: str = Field(..., description="Element type (e.g., button, icon, input)")
    label: Optional[str] = Field(None, description="Inferred text label or caption")
    confidence: float = Field(..., description="Model detection confidence score")

class ParseResponse(BaseModel):
    status: str
    elements: List[UIElement]
    width: float
    height: float
    latency_ms: int
