import json
import pytest
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient

from render_adapter.server import app
import render_adapter.server as server_module

def test_health_endpoint(client: TestClient) -> None:
    mock_client = AsyncMock()
    mock_client.health_check.return_value = True
    with patch("render_adapter.server.hermes_client", mock_client):
        resp = client.get("/health")
        assert resp.status_code == 200
        data = resp.json()
        assert data["status"] == "ok"
        assert data["hermes_connected"] is True

def test_agent_card_endpoint(client: TestClient) -> None:
    resp = client.get("/agent-card")
    assert resp.status_code == 200
    data = resp.json()
    assert data["id"] == "render-adapter-python"
    assert "skills" in data

@pytest.mark.asyncio
async def test_api_chat_endpoint(client: TestClient, mock_hermes_response: dict) -> None:
    mock_client = AsyncMock()
    mock_client.send_message.return_value = mock_hermes_response
    with patch("render_adapter.server.hermes_client", mock_client):
        chat_payload = {
            "text": "show me the dashboard",
            "session_id": "test-chat-session"
        }
        resp = client.post("/api/chat", json=chat_payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["session_id"] == "test-chat-session"
        assert data["status"] == "completed"
        assert data["ui_tree"]["component"] == "InfoCard"
        assert data["ui_tree"]["props"]["title"] == "Test"
        mock_client.send_message.assert_called_once()

@pytest.mark.asyncio
async def test_a2a_tasks_endpoint(client: TestClient, mock_hermes_response: dict) -> None:
    mock_client = AsyncMock()
    mock_client.send_message.return_value = mock_hermes_response
    with patch("render_adapter.server.hermes_client", mock_client):
        task_payload = {
            "task": "turn on the kitchen light",
            "session_id": "test-a2a-session"
        }
        resp = client.post("/a2a/tasks", json=task_payload)
        assert resp.status_code == 200
        data = resp.json()
        assert data["uiTree"]["component"] == "InfoCard"
        assert data["uiTree"]["props"]["title"] == "Test"
        mock_client.send_message.assert_called_once()

def test_websocket_a2ui_endpoint(client: TestClient, mock_hermes_response: dict) -> None:
    mock_client = AsyncMock()
    mock_client.send_message.return_value = mock_hermes_response
    with patch("render_adapter.server.hermes_client", mock_client):
        session_id = "test-ws-session"
        with client.websocket_connect(f"/ws/a2ui/{session_id}") as websocket:
            event_payload = {
                "type": "user_event",
                "action": "tap",
                "payload": {"componentId": "kitchen_switch"}
            }
            websocket.send_text(json.dumps(event_payload))
            
            data = websocket.receive_text()
            resp = json.loads(data)
            
            assert resp["type"] == "render"
            assert resp["surfaceId"] == "main"
            assert resp["uiTree"]["component"] == "InfoCard"
            assert resp["uiTree"]["props"]["title"] == "Test"
            mock_client.send_message.assert_called_once()
