#!/usr/bin/env bash
# setup-all.sh — Master setup script: runs all setup steps in order
# Usage: bash setup-all.sh [path-to-claude-config-tarball]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"
source "${SCRIPT_DIR}/lib/config.sh"

TARBALL="${1:-}"
PLATFORM="$(detect_platform)"

echo ""
echo "======================================================="
echo "  Claude Code Dev Environment — Full Setup (${PLATFORM})"
echo "======================================================="
echo ""

# If no setup.conf, run interactive config (with migration detection)
if [ ! -f "${SCRIPT_DIR}/setup.conf" ]; then
  prompt_config
  echo ""
fi

load_config
validate_config

echo "This will install and configure:"
echo "  - nvm, Node ${NODE_VERSION}, pnpm"
if [[ "${INSTALL_BUN}" == "true" ]]; then
  echo "  - Bun"
fi
echo "  - gh, Claude Code"
if [[ "${INSTALL_DOPPLER}" == "true" ]]; then
  echo "  - Doppler CLI"
fi
echo "  - MCP servers: ${MCP_SERVERS}"
echo "  - Shell configuration ($(basename "$(get_shell_rc)"))"
echo "  - Directory structure (${PROJECTS_ROOT})"
echo "  - .mcp.json and IDE workspace"
echo "  - Claude Code defaults (status line, accept edits)"
if [ -n "$TARBALL" ]; then
  echo "  - Claude config import from: ${TARBALL}"
fi
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "Aborted."
  exit 0
fi

echo ""
echo "Step 1/8: Installing tools..."
echo "──────────────────────────────"
bash "${SCRIPT_DIR}/install-tools.sh"

# Reload shell environment for nvm/pnpm/bun
export NVM_DIR="${HOME}/.nvm"
[ -s "${NVM_DIR}/nvm.sh" ] && . "${NVM_DIR}/nvm.sh"
export PNPM_HOME="${HOME}/.local/share/pnpm"
export PATH="${PNPM_HOME}:${PATH}"
if [[ "${INSTALL_BUN}" == "true" ]]; then
  export BUN_INSTALL="${HOME}/.bun"
  export PATH="${BUN_INSTALL}/bin:${PATH}"
fi

echo ""
echo "Step 2/8: Installing MCP packages..."
echo "─────────────────────────────────────"
bash "${SCRIPT_DIR}/install-mcp-packages.sh"

echo ""
echo "Step 3/8: Configuring shell..."
echo "──────────────────────────────"
bash "${SCRIPT_DIR}/configure-shell.sh"

echo ""
echo "Step 4/8: Creating directories..."
echo "─────────────────────────────────"
bash "${SCRIPT_DIR}/configure-directories.sh"

echo ""
echo "Step 5/8: Generating .mcp.json..."
echo "─────────────────────────────────"
bash "${SCRIPT_DIR}/generate-mcp-json.sh"

echo ""
echo "Step 6/8: Generating IDE workspace..."
echo "──────────────────────────────────────"
bash "${SCRIPT_DIR}/generate-workspace.sh"

echo ""
echo "Step 7/8: Installing defaults..."
echo "─────────────────────────────────"
bash "${SCRIPT_DIR}/install-defaults.sh"

# Import Claude config if tarball provided
if [ -n "$TARBALL" ]; then
  echo ""
  echo "Step 8/8: Importing Claude config..."
  echo "─────────────────────────────────────"
  bash "${SCRIPT_DIR}/import-claude-config.sh" "$TARBALL"
  bash "${SCRIPT_DIR}/patch-project-settings.sh"
else
  echo ""
  echo "Step 8/8: Claude config import..."
  echo "─────────────────────────────────"
  skip "No tarball provided. Run export-claude-config.sh on the source"
  info "machine, then: bash import-claude-config.sh <tarball>"
fi

echo ""
echo "======================================================="
echo "  Setup complete! Running verification..."
echo "======================================================="
echo ""
RC_FILE="$(get_shell_rc)"
source "$RC_FILE" 2>/dev/null || true
bash "${SCRIPT_DIR}/verify.sh" || true

echo ""
echo "── Remaining Manual Steps ──"
echo ""
echo "  1. Generate SSH key:  ssh-keygen -t ed25519"
echo "  2. Add key to GitHub: cat ~/.ssh/id_ed25519.pub"
echo "  3. Auth GitHub CLI:   gh auth login"
if [[ "${INSTALL_DOPPLER}" == "true" ]]; then
  echo "  4. Auth Doppler:      doppler login"
  if [[ -n "${DOPPLER_PROJECT}" ]]; then
    echo "  5. Setup Doppler:     cd ${PROJECTS_ROOT} && doppler setup"
    echo "     (project: ${DOPPLER_PROJECT}, config: ${DOPPLER_CONFIG})"
  fi
fi
echo "  - Create .env:       cp .env.example .env && edit .env"
echo "  - Open IDE:          code dev-env.code-workspace"
echo "                   or: cursor dev-env.code-workspace"
echo ""
echo "See setup/MANUAL-STEPS.md for full details."
