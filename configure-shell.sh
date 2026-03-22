#!/usr/bin/env bash
# configure-shell.sh — Add required blocks to shell RC file (.bashrc or .zshrc)
# Idempotent: uses marker comments to skip existing blocks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

PLATFORM="$(detect_platform)"
RC_FILE="$(get_shell_rc)"

section_header "Configuring $(basename "$RC_FILE") (${PLATFORM})"

# Ensure RC file exists
touch "$RC_FILE"

# ── nvm ──
add_shell_block "$RC_FILE" "nvm" 'export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

# ── Bun (conditional) ──
if [[ "${INSTALL_BUN}" == "true" ]]; then
  add_shell_block "$RC_FILE" "bun" 'export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
fi

# ── pnpm ──
add_shell_block "$RC_FILE" "pnpm" 'export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac'

# ── Claude Code (with or without Doppler wrapper) ──
if [[ "${SECRETS_MANAGER}" == "doppler" ]]; then
  add_shell_block "$RC_FILE" "claude" 'claude() {
  doppler run -- claude "$@"
}'
else
  add_shell_block "$RC_FILE" "claude" '# Claude Code — no secrets wrapper
# If using a secrets manager, set SECRETS_MANAGER in setup.conf'
fi

# ── Editor detection (platform-aware) ──
IDES="$(detect_ides)"
EDITOR_BLOCK=""

if [ -n "$IDES" ]; then
  for ide in $IDES; do
    local_cli="$(get_ide_cli "$ide")"
    if [[ "$ide" == "vscode" ]]; then
      EDITOR_BLOCK="${EDITOR_BLOCK}alias vscode=${local_cli}
"
    elif [[ "$ide" == "cursor" ]]; then
      EDITOR_BLOCK="${EDITOR_BLOCK}alias cursor=${local_cli}
"
    fi
  done

  # Set EDITOR to last found IDE (prefer cursor if both exist)
  if echo "$IDES" | grep -q "cursor"; then
    EDITOR_BLOCK="${EDITOR_BLOCK}export EDITOR=\"cursor --wait\""
  else
    EDITOR_BLOCK="${EDITOR_BLOCK}export EDITOR=\"code --wait\""
  fi

  add_shell_block "$RC_FILE" "editor" "$EDITOR_BLOCK"
else
  warn "Could not detect VS Code or Cursor. Add editor alias manually."
  add_shell_block "$RC_FILE" "editor" '# TODO: Set editor aliases for your IDE(s)
# alias vscode="code"
# alias cursor="cursor"
export EDITOR="code --wait"'
fi

# ── SSH agent auto-start (platform-aware) ──
SSH_BLOCK="$(get_ssh_agent_block)"
add_shell_block "$RC_FILE" "ssh-agent" "$SSH_BLOCK"

echo ""
echo "Done. Run: source ${RC_FILE}"
echo "Then: bash configure-directories.sh"
