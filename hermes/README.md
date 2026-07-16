# Hermes Agent — Setup & Configuration

This directory contains the Hermes Agent configuration for the Home Steward project.

## Prerequisites

1. **Install Hermes Agent:**

   **Windows (PowerShell):**
   ```powershell
   iex (irm https://hermes-agent.nousresearch.com/install.ps1)
   ```

   **Linux/macOS/WSL2:**
   ```bash
   curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
   source ~/.bashrc
   ```

2. **Install a model backend** (Ollama recommended for local dev):
   ```bash
   # Install Ollama: https://ollama.com/download
   ollama pull hermes3
   ```

## Quick Setup

Run the setup script from the repo root:

```powershell
# Windows
.\scripts\setup_hermes.ps1

# Linux/macOS
./scripts/setup_hermes.sh
```

The script will:
1. Verify Hermes is installed
2. Copy `config.yaml` → `~/.hermes/config.yaml`
3. Copy `custom_tools/render_ui.py` → `~/.hermes/custom_tools/`
4. Create `~/.hermes/.env` from `env.example` (prompts for secrets)
5. Run `hermes config check` to validate

## Manual Setup

1. Copy config: `cp hermes/config.yaml ~/.hermes/config.yaml`
2. Copy tools: `cp hermes/custom_tools/*.py ~/.hermes/custom_tools/`
3. Copy and edit env: `cp hermes/env.example ~/.hermes/.env` — fill in your keys
4. Validate: `hermes config check`

## Running

```bash
# Start the API server
hermes gateway

# Verify it's running
curl http://127.0.0.1:8642/health

# Test a completion
curl http://127.0.0.1:8642/v1/chat/completions \
  -H "Authorization: Bearer YOUR_API_SERVER_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"hermes-agent","messages":[{"role":"user","content":"Hello"}]}'
```

## Directory Contents

| File | Purpose |
|---|---|
| `config.yaml` | Main Hermes config (model, MCP servers, skills) |
| `env.example` | Template for `~/.hermes/.env` (secrets) |
| `custom_tools/render_ui.py` | The `render_ui` tool registration |
| `skills/` | Project-specific skills (device control, UI styles) |

## Skills

Skills follow the [agentskills.io](https://agentskills.io) standard:

- `device-control-ha/` — Home Assistant device control behavior
- `ui-style-minimal/` — Minimal card UI style (M4)
- `ui-style-dashboard/` — Dashboard UI style (M4)
