import pytest
from fastapi.testclient import TestClient
from typing import Any

from render_adapter.server import app
from render_adapter.hitl import HITLGate

@pytest.fixture
def client() -> TestClient:
    return TestClient(app)

@pytest.fixture
def mock_hermes_response() -> dict[str, Any]:
    return {
        "id": "chatcmpl-123",
        "object": "chat.completion",
        "created": 1677652288,
        "model": "hermes-agent",
        "choices": [{
            "index": 0,
            "message": {
                "role": "assistant",
                "content": None,
                "tool_calls": [{
                    "id": "call_123",
                    "type": "function",
                    "function": {
                        "name": "render_ui",
                        "arguments": '{"surfaceId": "main", "root": {"component": "InfoCard", "props": {"title": "Test", "body": "Hello World"}}}'
                    }
                }]
            },
            "finish_reason": "tool_calls"
        }]
    }

@pytest.fixture
def hitl_gate() -> HITLGate:
    return HITLGate()
