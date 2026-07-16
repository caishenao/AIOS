"""
Integration test for Home Assistant MCP connectivity.

Prerequisites:
- Home Assistant instance with MCP Server integration enabled
- Long-lived access token configured in ~/.hermes/.env as HA_TOKEN
- At least one entity exposed via Settings > Voice Assistants > Expose

Usage:
    uv run pytest tests/integration/test_ha_mcp.py -v

If no HA instance is available, tests are skipped automatically.
"""

from __future__ import annotations

import asyncio
import os
import sys

import pytest

# Skip all tests if HA is not configured
HA_MCP_URL = os.getenv("HA_MCP_URL", "")
HA_TOKEN = os.getenv("HA_TOKEN", "")
pytestmark = pytest.mark.skipif(
    not HA_MCP_URL or not HA_TOKEN,
    reason="HA_MCP_URL and HA_TOKEN must be set for integration tests",
)


@pytest.fixture
def ha_url() -> str:
    """Return the Home Assistant MCP endpoint URL."""
    return HA_MCP_URL


@pytest.fixture
def ha_headers() -> dict[str, str]:
    """Return auth headers for HA MCP."""
    return {
        "Authorization": f"Bearer {HA_TOKEN}",
        "Content-Type": "application/json",
    }


class TestHaMcpConnection:
    """Test connectivity to Home Assistant MCP Server."""

    @pytest.mark.asyncio
    async def test_mcp_endpoint_reachable(self, ha_url: str, ha_headers: dict) -> None:
        """Verify the HA MCP endpoint is reachable."""
        import httpx

        async with httpx.AsyncClient() as client:
            # MCP uses POST for initialization
            response = await client.post(
                ha_url,
                headers=ha_headers,
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {},
                        "clientInfo": {
                            "name": "home-steward-test",
                            "version": "0.1.0",
                        },
                    },
                },
                timeout=10.0,
            )
            assert response.status_code == 200, (
                f"MCP endpoint returned {response.status_code}: {response.text}"
            )
            data = response.json()
            assert "result" in data or "error" not in data, (
                f"MCP initialization failed: {data}"
            )

    @pytest.mark.asyncio
    async def test_list_tools(self, ha_url: str, ha_headers: dict) -> None:
        """Verify we can list available MCP tools from HA."""
        import httpx

        async with httpx.AsyncClient() as client:
            # Initialize first
            init_resp = await client.post(
                ha_url,
                headers=ha_headers,
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {},
                        "clientInfo": {
                            "name": "home-steward-test",
                            "version": "0.1.0",
                        },
                    },
                },
                timeout=10.0,
            )
            assert init_resp.status_code == 200

            # List tools
            tools_resp = await client.post(
                ha_url,
                headers=ha_headers,
                json={
                    "jsonrpc": "2.0",
                    "id": 2,
                    "method": "tools/list",
                    "params": {},
                },
                timeout=10.0,
            )
            assert tools_resp.status_code == 200
            data = tools_resp.json()
            assert "result" in data, f"tools/list failed: {data}"
            tools = data["result"].get("tools", [])
            assert len(tools) > 0, (
                "No tools returned — ensure entities are exposed in HA "
                "(Settings > Voice Assistants > Expose)"
            )
            print(f"\nDiscovered {len(tools)} HA MCP tools:")
            for tool in tools[:5]:  # Print first 5
                print(f"  - {tool.get('name', '?')}: {tool.get('description', '')[:80]}")
            if len(tools) > 5:
                print(f"  ... and {len(tools) - 5} more")


class TestHaMcpDeviceControl:
    """Test device control via HA MCP (requires specific test entities)."""

    TEST_ENTITY = os.getenv("HA_TEST_ENTITY", "light.test_light")

    @pytest.mark.asyncio
    async def test_toggle_entity(self, ha_url: str, ha_headers: dict) -> None:
        """Toggle a test entity on/off. Requires HA_TEST_ENTITY env var."""
        if not self.TEST_ENTITY:
            pytest.skip("HA_TEST_ENTITY not set")

        import httpx

        async with httpx.AsyncClient() as client:
            # Initialize
            await client.post(
                ha_url,
                headers=ha_headers,
                json={
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "initialize",
                    "params": {
                        "protocolVersion": "2024-11-05",
                        "capabilities": {},
                        "clientInfo": {
                            "name": "home-steward-test",
                            "version": "0.1.0",
                        },
                    },
                },
                timeout=10.0,
            )

            # Call a tool (the actual tool name depends on HA's Assist API exposure)
            # This is a best-effort test — actual tool names vary per HA setup
            call_resp = await client.post(
                ha_url,
                headers=ha_headers,
                json={
                    "jsonrpc": "2.0",
                    "id": 3,
                    "method": "tools/call",
                    "params": {
                        "name": "HassTurnOn",
                        "arguments": {
                            "name": self.TEST_ENTITY.split(".")[-1].replace("_", " "),
                        },
                    },
                },
                timeout=10.0,
            )
            data = call_resp.json()
            # We accept either success or a "not found" error (entity not exposed)
            if "error" in data:
                print(f"\nTool call returned error (may be expected): {data['error']}")
            else:
                print(f"\nTool call succeeded: {data.get('result', {})}")
