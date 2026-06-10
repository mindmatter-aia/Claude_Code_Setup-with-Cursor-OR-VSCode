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

# ── Homebrew (platform-aware) ──
# macOS Apple-Silicon: /opt/homebrew · macOS Intel: /usr/local · Linux: linuxbrew.
# Resolved at shell-init via the first brew that exists, so the same block is
# correct on every machine (replaces the WSL2-hardcoded HOMEBREW_PREFIX export).
add_shell_block "$RC_FILE" "homebrew" 'for _brew in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
  if [ -x "$_brew" ]; then eval "$("$_brew" shellenv)"; break; fi
done
unset _brew'

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

# ── Claude Code (with or without Doppler wrapper) + /prime shortcuts ──
# cs = prime a normal session; cr = prime with skip-permissions (review before
# relying on cr — it bypasses tool approvals).
if [[ "${SECRETS_MANAGER}" == "doppler" ]]; then
  CLAUDE_BLOCK="$(cat <<'EOF'
claude() {
  doppler run -- claude "$@"
}
alias cs='claude "/prime"'
alias cr='claude --dangerously-skip-permissions "/prime"'
EOF
)"
else
  CLAUDE_BLOCK="$(cat <<'EOF'
# Claude Code — no secrets wrapper
# If using a secrets manager, set SECRETS_MANAGER in setup.conf
alias cs='claude "/prime"'
alias cr='claude --dangerously-skip-permissions "/prime"'
EOF
)"
fi
add_shell_block "$RC_FILE" "claude" "$CLAUDE_BLOCK"

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

# ── Telemetry opt-out ──
add_shell_block "$RC_FILE" "telemetry-opt-out" 'export DO_NOT_TRACK=1
export NEXT_TELEMETRY_DISABLED=1'

echo ""
echo "Done. Run: source ${RC_FILE}"
echo "Then: bash configure-directories.sh"
