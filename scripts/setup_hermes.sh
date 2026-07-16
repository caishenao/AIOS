#!/usr/bin/env bash
set -euo pipefail

# Home Steward — Hermes Agent Setup (Linux/macOS/WSL2)

HERMES_HOME="${HOME}/.hermes"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
HERMES_DIR="${REPO_ROOT}/hermes"

echo "=== Home Steward — Hermes Setup ==="
echo ""

# --- 1. Check Hermes installation ---
echo "[1/5] Checking Hermes installation..."
if ! command -v hermes &> /dev/null; then
    echo "  Hermes not found. Install with:"
    echo "    curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    echo "    source ~/.bashrc"
    echo "  Then re-run this script."
    exit 1
fi
echo "  Found: $(which hermes)"

# --- 2. Copy config.yaml ---
echo "[2/5] Copying config.yaml..."
mkdir -p "${HERMES_HOME}"
CONFIG_DST="${HERMES_HOME}/config.yaml"
if [ -f "${CONFIG_DST}" ]; then
    BACKUP="${CONFIG_DST}.bak.$(date +%Y%m%d%H%M%S)"
    cp "${CONFIG_DST}" "${BACKUP}"
    echo "  Backed up existing config → ${BACKUP}"
fi
cp "${HERMES_DIR}/config.yaml" "${CONFIG_DST}"
echo "  Copied → ${CONFIG_DST}"

# --- 3. Copy custom tools ---
echo "[3/5] Copying custom tools..."
TOOLS_DST="${HERMES_HOME}/custom_tools"
mkdir -p "${TOOLS_DST}"
if [ -d "${HERMES_DIR}/custom_tools" ]; then
    cp -r "${HERMES_DIR}/custom_tools/"* "${TOOLS_DST}/"
    echo "  Copied custom tools → ${TOOLS_DST}"
else
    echo "  No custom_tools directory found, skipping."
fi

# --- 4. Create .env ---
echo "[4/5] Setting up .env..."
ENV_DST="${HERMES_HOME}/.env"
if [ -f "${ENV_DST}" ]; then
    echo "  .env already exists, skipping (edit manually if needed)."
else
    cp "${HERMES_DIR}/env.example" "${ENV_DST}"
    chmod 600 "${ENV_DST}"
    echo "  Created ${ENV_DST} from template."
    echo "  *** IMPORTANT: Edit ${ENV_DST} and fill in your API keys! ***"
fi

# --- 5. Validate ---
echo "[5/5] Validating configuration..."
if hermes config check 2>&1 | sed 's/^/  /'; then
    echo "  Configuration valid!"
else
    echo "  Validation failed — check config.yaml and .env"
fi

echo ""
echo "=== Setup complete! ==="
echo "Next steps:"
echo "  1. Edit ~/.hermes/.env with your API keys"
echo "  2. Start Ollama: ollama serve"
echo "  3. Pull model: ollama pull hermes3"
echo "  4. Start Hermes: hermes gateway"
echo "  5. Test: curl http://127.0.0.1:8642/health"
