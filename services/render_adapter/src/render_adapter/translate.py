from typing import Any
from pydantic import BaseModel, Field

# --- A2UI Server to Client Messages ---

class A2UIMessage(BaseModel):
    type: str

class A2UIRenderMessage(A2UIMessage):
    type: str = "render"
    surface_id: str = Field(alias="surfaceId")
    style_skill: str | None = Field(None, alias="styleSkill")
    ui_tree: dict[str, Any] = Field(alias="uiTree")

class A2UIPatchMessage(A2UIMessage):
    type: str = "patch"
    surface_id: str = Field(alias="surfaceId")
    path: str
    operations: list[dict[str, Any]]

class A2UIDataUpdateMessage(A2UIMessage):
    type: str = "data_update"
    surface_id: str = Field(alias="surfaceId")
    bindings: dict[str, Any]

class A2UIEventAckMessage(A2UIMessage):
    type: str = "event_ack"
    event_id: str = Field(alias="eventId")
    status: str

# --- A2UI Client to Server Messages ---

class ClientEvent(BaseModel):
    action: str
    payload: dict[str, Any] = Field(default_factory=dict)

def translate_to_a2ui(render_ui_payload: dict[str, Any]) -> A2UIRenderMessage:
    """Translate a validated render_ui payload to an A2UI render message."""
    return A2UIRenderMessage(
        surfaceId=render_ui_payload.get("surfaceId", "main"),
        styleSkill=render_ui_payload.get("styleSkill"),
        uiTree=render_ui_payload.get("root", {})
    )

def parse_client_event(raw_message: dict[str, Any]) -> ClientEvent:
    """Parse an incoming client user_event."""
    return ClientEvent(
        action=raw_message.get("action", "unknown"),
        payload=raw_message.get("payload", {})
    )
