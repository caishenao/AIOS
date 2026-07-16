#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup Hermes Agent for the Home Steward project.
.DESCRIPTION
    Copies configuration files, custom tools, and skills to ~/.hermes/,
    creates .env from template, and validates the configuration.
#>

$ErrorActionPreference = "Stop"
$HermesHome = Join-Path $env:USERPROFILE ".hermes"
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
# If run from repo root via .\scripts\setup_hermes.ps1, adjust:
if (-not (Test-Path (Join-Path $RepoRoot "AGENTS.md"))) {
    $RepoRoot = Split-Path -Parent $PSScriptRoot
    if (-not (Test-Path (Join-Path $RepoRoot "AGENTS.md"))) {
        $RepoRoot = Get-Location
    }
}
$HermesDir = Join-Path $RepoRoot "hermes"

Write-Host "=== Home Steward — Hermes Setup ===" -ForegroundColor Cyan
Write-Host ""

# --- 1. Check Hermes installation ---
Write-Host "[1/5] Checking Hermes installation..." -ForegroundColor Yellow
$hermesCmd = Get-Command hermes -ErrorAction SilentlyContinue
if (-not $hermesCmd) {
    Write-Host "  Hermes not found. Installing..." -ForegroundColor Red
    Write-Host "  Run: iex (irm https://hermes-agent.nousresearch.com/install.ps1)" -ForegroundColor White
    Write-Host "  Then re-run this script." -ForegroundColor White
    exit 1
}
Write-Host "  Found: $($hermesCmd.Source)" -ForegroundColor Green

# --- 2. Copy config.yaml ---
Write-Host "[2/5] Copying config.yaml..." -ForegroundColor Yellow
if (-not (Test-Path $HermesHome)) {
    New-Item -ItemType Directory -Path $HermesHome -Force | Out-Null
}
$configSrc = Join-Path $HermesDir "config.yaml"
$configDst = Join-Path $HermesHome "config.yaml"
if (Test-Path $configDst) {
    $backup = "${configDst}.bak.$(Get-Date -Format 'yyyyMMddHHmmss')"
    Copy-Item $configDst $backup
    Write-Host "  Backed up existing config → $backup" -ForegroundColor DarkGray
}
Copy-Item $configSrc $configDst -Force
Write-Host "  Copied → $configDst" -ForegroundColor Green

# --- 3. Copy custom tools ---
Write-Host "[3/5] Copying custom tools..." -ForegroundColor Yellow
$toolsDir = Join-Path $HermesHome "custom_tools"
if (-not (Test-Path $toolsDir)) {
    New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
}
$toolsSrc = Join-Path $HermesDir "custom_tools"
if (Test-Path $toolsSrc) {
    Copy-Item (Join-Path $toolsSrc "*") $toolsDir -Force -Recurse
    Write-Host "  Copied custom tools → $toolsDir" -ForegroundColor Green
} else {
    Write-Host "  No custom_tools directory found, skipping." -ForegroundColor DarkGray
}

# --- 4. Create .env ---
Write-Host "[4/5] Setting up .env..." -ForegroundColor Yellow
$envDst = Join-Path $HermesHome ".env"
$envSrc = Join-Path $HermesDir "env.example"
if (Test-Path $envDst) {
    Write-Host "  .env already exists, skipping (edit manually if needed)." -ForegroundColor DarkGray
} else {
    Copy-Item $envSrc $envDst
    Write-Host "  Created $envDst from template." -ForegroundColor Green
    Write-Host "  *** IMPORTANT: Edit $envDst and fill in your API keys! ***" -ForegroundColor Red
}

# --- 5. Validate ---
Write-Host "[5/5] Validating configuration..." -ForegroundColor Yellow
try {
    & hermes config check 2>&1 | ForEach-Object { Write-Host "  $_" }
    Write-Host "  Configuration valid!" -ForegroundColor Green
} catch {
    Write-Host "  Validation failed — check config.yaml and .env" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
}

Write-Host ""
Write-Host "=== Setup complete! ===" -ForegroundColor Cyan
Write-Host "Next steps:" -ForegroundColor White
Write-Host "  1. Edit ~/.hermes/.env with your API keys" -ForegroundColor White
Write-Host "  2. Start Ollama: ollama serve" -ForegroundColor White
Write-Host "  3. Pull model: ollama pull hermes3" -ForegroundColor White
Write-Host "  4. Start Hermes: hermes gateway" -ForegroundColor White
Write-Host "  5. Test: curl http://127.0.0.1:8642/health" -ForegroundColor White
