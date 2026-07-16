import time
from fastapi import FastAPI, HTTPException
from .models import ParseRequest, ParseResponse, UIElement
from .parser import OmniParserWrapper

app = FastAPI(title="OmniParser Local Screen Parsing Service")
parser = OmniParserWrapper()

@app.on_event("startup")
def startup_event():
    # Attempt to load models on startup
    parser.load_models()

@app.get("/health")
def health():
    import torch
    cuda_available = torch.cuda.is_available()
    device_name = torch.cuda.get_device_name(0) if cuda_available else "CPU"
    
    return {
        "status": "healthy",
        "models_loaded": parser.models_loaded,
        "gpu_available": cuda_available,
        "device": device_name,
        "weights_present": {
            "detect": os.path.exists(parser.detect_model_path),
            "caption": os.path.exists(parser.caption_model_path)
        } if 'os' in globals() else {}
    }

@app.post("/parse", response_model=ParseResponse)
def parse_screen(request: ParseRequest):
    start_time = time.time()
    try:
        result = parser.parse(request.image)
        elements = [
            UIElement(
                bbox=e["bbox"],
                type=e["type"],
                label=e.get("label"),
                confidence=e["confidence"]
            )
            for e in result["elements"]
        ]
        
        latency = int((time.time() - start_time) * 1000)
        
        return ParseResponse(
            status="success",
            elements=elements,
            width=result["width"],
            height=result["height"],
            latency_ms=latency
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

import os # Ensure os is imported for health check path query
