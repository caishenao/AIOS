# MCP Transport Proxy

This service provides transport unification for MCP servers with different
transport mechanisms. It bridges between stdio, SSE/HTTP, and MQTT transports
so that Hermes can communicate with all device MCP servers uniformly.

## When Is This Needed?

| MCP Server | Native Transport | Proxy Needed? |
|---|---|---|
| Home Assistant | Streamable HTTP | ❌ No — Hermes connects directly |
| ESP RainMaker | stdio | ❌ No — Hermes supports stdio natively |
| ESP32 over MQTT | MQTT 5.0 | ✅ Yes — needs MQTT ↔ HTTP bridge |
| ESP32 WebSocket | WebSocket | ⚠️ Maybe — depends on Hermes WS support |

## Architecture

```
Hermes MCP Client
    │
    ├── HTTP ──────→ Home Assistant /api/mcp
    ├── stdio ─────→ ESP RainMaker MCP Server
    └── HTTP ──────→ mcp_proxy (this service)
                         │
                         └── MQTT 5.0 ──→ ESP32 devices
```

## Tools Used

### mcp-proxy (PyPI)

For stdio ↔ SSE/HTTP bridging:

```bash
pip install mcp-proxy
# or
uv tool install mcp-proxy

# Expose a stdio server over HTTP
mcp-proxy --transport streamable-http --port 8080 -- python my_server.py

# Connect to a remote SSE server as stdio
mcp-proxy --transport stdio --sse-url http://remote:8080/sse
```

### Custom MQTT Bridge

For ESP32 MQTT devices, a custom bridge is needed (see `mqtt_bridge.py`):

```
ESP32 ──MQTT──→ EMQX Broker ──→ mqtt_bridge.py ──stdio──→ mcp-proxy ──HTTP──→ Hermes
```

## Setup (M2+)

1. Install dependencies: `cd services/mcp_proxy && uv sync`
2. Configure MQTT broker connection in `.env`
3. Start the bridge: `uv run python -m mcp_proxy.bridge`

## Status

- **M2**: Not required (HA uses direct HTTP)
- **M2+**: ESP RainMaker stdio works natively with Hermes
- **Future**: MQTT bridge for ESP32 direct control
