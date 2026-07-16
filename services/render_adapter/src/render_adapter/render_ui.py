import json
from typing import Any
from ui_spec.validator import validate_render_ui

# This schema matches the one in hermes/custom_tools/render_ui.py
RENDER_UI_TOOL_SCHEMA = {
    "name": "render_ui",
    "description": "Render a native UI on the user's current device surface.",
    "parameters": {
        "type": "object",
        "required": ["surfaceId", "root"],
        "properties": {
            "surfaceId": {"type": "string"},
            "styleSkill": {"type": "string"},
            "root": {
                "type": "object",
                "required": ["component"],
                "properties": {
                    "component": {"type": "string"},
                    "props": {"type": "object"},
                    "bindings": {"type": "object"},
                    "events": {"type": "object"},
                    "children": {
                        "type": "array",
                        "items": {"type": "object"} # Recursive definition simplified for the schema passed to LLM
                    }
                }
            }
        }
    }
}

def extract_render_ui_calls(hermes_response: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract render_ui tool call payloads from a Hermes response."""
    calls = []
    choices = hermes_response.get("choices", [])
    for choice in choices:
        message = choice.get("message", {})
        tool_calls = message.get("tool_calls", [])
        for tool_call in tool_calls:
            function = tool_call.get("function", {})
            if function.get("name") == "render_ui":
                try:
                    args = json.loads(function.get("arguments", "{}"))
                    calls.append(args)
                except json.JSONDecodeError:
                    pass
    return calls

def validate_and_process(payload: dict[str, Any]) -> dict[str, Any]:
    """Validate a render_ui payload and return it or a fallback on error."""
    is_valid, fallback = validate_render_ui(payload)
    if is_valid:
        return payload
    return fallback or {}
