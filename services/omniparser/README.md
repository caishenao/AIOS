# OmniParser Local Service (Tier 3 Screen-Parser)

This is a local Python microservice that wraps Microsoft's **OmniParser v2** for structured UI screen parsing.

It detect interactable screen elements (YOLOv8) and captions them (Florence-2) to produce UI structure JSON for the AIOS agent.

## GPU Requirements
- NVIDIA GPU with **4GB+ VRAM** (8GB+ recommended)
- CUDA Toolkit installed

## Setup & Deployment

1. **Install dependencies** (requires `uv` or `pip`):
   ```bash
   cd services/omniparser
   uv sync
   ```

2. **Download Weights**:
   Download Microsoft's OmniParser v2 weights and place them under `weights/` directory:
   - YOLOv8 weights: HuggingFace model `microsoft/OmniParser-v2` icon detection weights -> `weights/icon_detect/best.pt`
   - Florence-2 weights: `microsoft/OmniParser-v2` icon captioning weights -> `weights/icon_caption_florence/`

3. **Start the Service**:
   ```bash
   uv run python -m omniparser_server
   ```
   The server will run on `http://127.0.0.1:8200` by default.

## API Endpoints

- `GET /health` — Check server status, model loading status, and GPU availability.
- `POST /parse` — Parse a base64-encoded screenshot and return detected UI nodes.

## Mock Fallback Mode
If weights are not found or no GPU is available, the service runs in **Mock Mode**, returning predefined elements for baseline protocol validation without crashing.
