import json
import logging
import uuid
from typing import Any

from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from .config import get_settings
from .hermes_client import HermesClient
from .hitl import hitl_gate
from .render_ui import extract_render_ui_calls, validate_and_process
from .translate import parse_client_event
from .tasks import task_manager

logger = logging.getLogger(__name__)

app = FastAPI(title="Home Steward Render Adapter")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

hermes_client: HermesClient | None = None

@app.on_event("startup")
async def startup() -> None:
    global hermes_client
    settings = get_settings()
    hermes_client = HermesClient(settings.HERMES_URL, settings.HERMES_API_KEY, settings.HERMES_MODEL)
    logging.basicConfig(level=settings.LOG_LEVEL.upper())
    
    # Bind the completion callback to the WebSocket connection manager
    task_manager.set_completion_callback(manager.send_json)

@app.on_event("shutdown")
async def shutdown() -> None:
    if hermes_client:
        await hermes_client.close()

class ChatRequest(BaseModel):
    text: str
    session_id: str | None = None
    a2a_agents: list[dict[str, Any]] | None = None

class ChatResponse(BaseModel):
    session_id: str
    status: str
    ui_tree: dict[str, Any] | None = None
    text_reply: str | None = None

@app.get("/health")
async def health_check() -> dict[str, Any]:
    if not hermes_client:
        return {"status": "starting"}
    hermes_ok = await hermes_client.health_check()
    return {
        "status": "ok" if hermes_ok else "degraded",
        "hermes_connected": hermes_ok
    }

class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: dict[str, WebSocket] = {}

    async def connect(self, websocket: WebSocket, session_id: str) -> None:
        await websocket.accept()
        self.active_connections[session_id] = websocket

    def disconnect(self, session_id: str) -> None:
        self.active_connections.pop(session_id, None)

    async def send_json(self, session_id: str, data: dict[str, Any]) -> None:
        if session_id in self.active_connections:
            await self.active_connections[session_id].send_json(data)

manager = ConnectionManager()

def build_ui_from_response(response: dict[str, Any]) -> tuple[dict[str, Any] | None, str | None]:
    """Extract UI tree and/or text from a Hermes/DeepSeek response."""
    render_calls = extract_render_ui_calls(response)
    
    # Get text content as fallback
    text_content = None
    choices = response.get("choices", [])
    if choices:
        text_content = choices[0].get("message", {}).get("content")
    
    if render_calls:
        validated = validate_and_process(render_calls[0])
        return validated.get("root"), text_content
    elif text_content:
        # Wrap plain text in an InfoCard
        return {
            "component": "InfoCard",
            "props": {"title": "Assistant", "body": text_content},
            "children": []
        }, text_content
    return None, text_content

@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest) -> ChatResponse:
    if not hermes_client:
        raise HTTPException(status_code=500, detail="Hermes client not initialized")
        
    session_id = request.session_id or str(uuid.uuid4())
    
    # Inject A2A agents context if available
    a2a_context = ""
    if request.a2a_agents:
        a2a_context = "\nAvailable A2A Agents on local network:\n"
        for agent in request.a2a_agents:
            a2a_context += f"- {agent.get('name')} (Endpoint: {agent.get('endpoint')}): {agent.get('description')}\n"
    
    messages = [{"role": "user", "content": request.text + a2a_context}]
    
    try:
        response = await hermes_client.send_message(
            session_id, 
            messages,
            a2a_agents=request.a2a_agents
        )
        ui_tree, text_reply = build_ui_from_response(response)
        
        return ChatResponse(
            session_id=session_id,
            status="completed",
            ui_tree=ui_tree,
            text_reply=text_reply,
        )
    except Exception as e:
        logger.error(f"Error calling LLM: {e}")
        return ChatResponse(
            session_id=session_id,
            status="error",
            text_reply=f"Error: {e}",
        )

class A2ATaskRequest(BaseModel):
    task: str | None = None
    intent: str | None = None
    session_id: str | None = None

@app.get("/agent-card")
async def agent_card() -> dict[str, Any]:
    return {
        "id": "render-adapter-python",
        "name": "Python Render Adapter (Hermes)",
        "description": "Hermes-powered AIOS backend render adapter node",
        "version": "1.0.0",
        "endpoint": "/a2a/tasks",
        "skills": ["chat", "ui_generation", "device_control"],
        "auth": "none"
    }

@app.post("/a2a/tasks")
@app.post("/task")
@app.post("/")
async def a2a_task(request: A2ATaskRequest) -> dict[str, Any]:
    if not hermes_client:
        raise HTTPException(status_code=500, detail="Hermes client not initialized")
    
    task_text = request.task or request.intent
    if not task_text:
        raise HTTPException(status_code=400, detail="Missing task or intent")
        
    session_id = request.session_id or str(uuid.uuid4())
    messages = [{"role": "user", "content": task_text}]
    
    try:
        response = await hermes_client.send_message(session_id, messages)
        ui_tree, text_reply = build_ui_from_response(response)
        return {
            "reply": text_reply,
            "uiTree": ui_tree
        }
    except Exception as e:
        logger.error(f"Error executing A2A task on Hermes: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.websocket("/ws/a2ui/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str) -> None:
    await manager.connect(websocket, session_id)
    try:
        while True:
            data = await websocket.receive_text()
            try:
                msg_dict = json.loads(data)
                event_type = msg_dict.get("type")
                
                if event_type == "user_event":
                    client_event = parse_client_event(msg_dict)
                    # Forward client event back to Hermes
                    if hermes_client:
                        messages = [{
                            "role": "user",
                            "content": f"User interaction: {client_event.action} with payload {json.dumps(client_event.payload)}"
                        }]
                        response = await hermes_client.send_message(session_id, messages)
                        ui_tree, text_reply = build_ui_from_response(response)
                        await manager.send_json(session_id, {
                            "type": "render",
                            "surfaceId": "main",
                            "uiTree": ui_tree,
                            "textReply": text_reply
                        })
                        
                elif event_type == "confirm_response":
                    confirmation_id = msg_dict.get("confirmationId")
                    confirmed = msg_dict.get("confirmed", False)
                    if confirmation_id:
                        hitl_gate.resolve(confirmation_id, confirmed)
                        
            except json.JSONDecodeError:
                logger.warning(f"Invalid JSON received on WS for session {session_id}")
            except Exception as e:
                logger.error(f"Error processing WS message: {e}")
                
    except WebSocketDisconnect:
        manager.disconnect(session_id)
