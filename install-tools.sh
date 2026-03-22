#!/usr/bin/env bash
# install-tools.sh — Install all development tools (cross-platform)
# Idempotent: safe to re-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

PLATFORM="$(detect_platform)"
PKG_MGR="$(get_package_manager)"

section_header "Dev Environment — Tool Installation (${PLATFORM})"

# ── System packages ──────────────────────────────────────────────
echo "── System packages ──"
case "$PKG_MGR" in
  brew)
    if ! command -v brew &> /dev/null; then
      err "Homebrew not found. Install it first: https://brew.sh"
      exit 1
    fi
    brew install git curl jq gh rsync 2>/dev/null || true
    log "System packages installed (brew)"
    ;;
  apt)
    sudo apt-get update -qq
    sudo apt-get install -y -qq git curl wget gnupg jq unzip build-essential rsync > /dev/null 2>&1
    log "System packages installed (apt)"
    ;;
esac

# ── nvm ──────────────────────────────────────────────────────────
echo ""
echo "── nvm (Node Version Manager) ──"
export NVM_DIR="${HOME}/.nvm"
if [ -s "${NVM_DIR}/nvm.sh" ]; then
  skip "nvm already installed"
  . "${NVM_DIR}/nvm.sh"
else
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  . "${NVM_DIR}/nvm.sh"
  log "nvm installed"
fi
info "nvm $(nvm --version)"

# ── Node.js ──────────────────────────────────────────────────────
echo ""
echo "── Node.js v${NODE_VERSION} LTS ──"
if nvm ls "${NODE_VERSION}" > /dev/null 2>&1; then
  skip "Node ${NODE_VERSION} already installed"
  nvm use "${NODE_VERSION}" > /dev/null
else
  nvm install "${NODE_VERSION}"
  nvm alias default "${NODE_VERSION}"
  log "Node ${NODE_VERSION} installed"
fi
info "node $(node --version)"
info "npm $(npm --version)"

# ── pnpm ─────────────────────────────────────────────────────────
echo ""
echo "── pnpm ──"
if command -v pnpm &> /dev/null; then
  skip "pnpm already installed"
else
  npm install -g pnpm
  log "pnpm installed"
fi
info "pnpm $(pnpm --version)"

# ── Bun (optional) ──────────────────────────────────────────────
if [[ "${INSTALL_BUN}" == "true" ]]; then
  echo ""
  echo "── Bun ──"
  if command -v bun &> /dev/null; then
    skip "Bun already installed"
  else
    curl -fsSL https://bun.sh/install | bash
    export BUN_INSTALL="${HOME}/.bun"
    export PATH="${BUN_INSTALL}/bin:${PATH}"
    log "Bun installed"
  fi
  info "bun $(bun --version)"
fi

# ── GitHub CLI ───────────────────────────────────────────────────
echo ""
echo "── GitHub CLI ──"
if command -v gh &> /dev/null; then
  skip "GitHub CLI already installed"
else
  case "$PKG_MGR" in
    brew)
      # gh already installed via brew above
      log "GitHub CLI installed (brew)"
      ;;
    apt)
      sudo mkdir -p -m 755 /etc/apt/keyrings
      wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg \
        | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
      sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
        | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
      sudo apt-get update -qq
      sudo apt-get install gh -y -qq > /dev/null 2>&1
      log "GitHub CLI installed (apt)"
      ;;
  esac
fi
info "gh $(gh --version | head -1)"

# ── Doppler CLI (optional) ──────────────────────────────────────
if [[ "${INSTALL_DOPPLER}" == "true" ]]; then
  echo ""
  echo "── Doppler CLI ──"
  if command -v doppler &> /dev/null; then
    skip "Doppler CLI already installed"
  else
    case "$PKG_MGR" in
      brew)
        brew install gnupg
        brew install dopplerhq/cli/doppler
        log "Doppler CLI installed (brew)"
        ;;
      apt)
        sudo apt-get install -y apt-transport-https ca-certificates > /dev/null 2>&1
        curl -sLf --retry 3 --tlsv1.2 --proto "=https" \
          'https://packages.doppler.com/public/cli/gpg.DE2A7741A397C129.key' \
          | sudo gpg --dearmor -o /usr/share/keyrings/doppler-archive-keyring.gpg
        echo "deb [signed-by=/usr/share/keyrings/doppler-archive-keyring.gpg] https://packages.doppler.com/public/cli/deb/debian any-version main" \
          | sudo tee /etc/apt/sources.list.d/doppler-cli.list > /dev/null
        sudo apt-get update -qq
        sudo apt-get install -y -qq doppler > /dev/null 2>&1
        log "Doppler CLI installed (apt)"
        ;;
    esac
  fi
  info "doppler $(doppler --version)"
fi

# ── Claude Code CLI ──────────────────────────────────────────────
echo ""
echo "── Claude Code CLI ──"
if command -v claude &> /dev/null; then
  skip "Claude Code already installed"
else
  npm install -g @anthropic-ai/claude-code
  log "Claude Code installed"
fi
info "claude $(claude --version 2>/dev/null || echo 'installed')"

echo ""
section_header "Tool installation complete!"
echo "  Run: source $(get_shell_rc)"
echo "  Then: bash install-mcp-packages.sh"
