from typing import Any
from render_adapter.render_ui import extract_render_ui_calls, validate_and_process

def test_extract_render_ui_calls(mock_hermes_response: dict[str, Any]) -> None:
    calls = extract_render_ui_calls(mock_hermes_response)
    assert len(calls) == 1
    assert calls[0]["surfaceId"] == "main"
    assert calls[0]["root"]["component"] == "InfoCard"

def test_validate_valid_payload() -> None:
    payload = {
        "surfaceId": "main",
        "root": {
            "component": "InfoCard",
            "props": {"title": "Test", "body": "Body text"}
        }
    }
    result = validate_and_process(payload)
    assert result == payload

def test_validate_invalid_payload_fallback() -> None:
    payload = {
        "surfaceId": "main",
        "root": {
            "component": "InfoCard",
            "props": {"title": "Test"} # Missing required 'body'
        }
    }
    result = validate_and_process(payload)
    assert result != payload
    assert result["root"]["component"] == "InfoCard"
    assert "UI Generation Error" in result["root"]["props"]["title"]
