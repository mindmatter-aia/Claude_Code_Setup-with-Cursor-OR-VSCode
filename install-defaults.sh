#!/usr/bin/env bash
# install-defaults.sh — Install Claude Code status line and user-level defaults
# Idempotent: overwrites statusline.sh, merges config into settings.json
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="${SCRIPT_DIR}/templates/statusline.sh"
TARGET="${HOME}/.claude/statusline.sh"
SETTINGS="${HOME}/.claude/settings.json"

echo "============================================"
echo "  Installing Claude Code User Defaults"
echo "============================================"
echo ""

# Ensure ~/.claude exists
mkdir -p "${HOME}/.claude"

# ── Status line script ──
if [ -f "$TEMPLATE" ]; then
  cp "$TEMPLATE" "$TARGET"
  chmod +x "$TARGET"
  echo -e "${GREEN}[OK]${NC} Installed statusline: ${TARGET}"
else
  echo -e "${YELLOW}[WARN]${NC} Statusline template not found: ${TEMPLATE}"
fi

# ── Settings.json defaults ──
# Merge statusLine and defaultMode into user settings
if [ -f "$SETTINGS" ]; then
  if command -v jq &> /dev/null; then
    CHANGED=false
    TMP=$(mktemp)
    cp "$SETTINGS" "$TMP"

    # Add defaultMode: acceptEdits if missing
    if ! jq -e '.permissions.defaultMode' "$TMP" > /dev/null 2>&1; then
      jq '.permissions.defaultMode = "acceptEdits"' "$TMP" > "${TMP}.out" && mv "${TMP}.out" "$TMP"
      echo -e "${GREEN}[OK]${NC} Set permissions.defaultMode = acceptEdits"
      CHANGED=true
    else
      echo -e "${YELLOW}[SKIP]${NC} defaultMode already configured"
    fi

    # Add statusLine if missing
    if ! jq -e '.statusLine' "$TMP" > /dev/null 2>&1; then
      jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh", "padding": 1}}' "$TMP" > "${TMP}.out" && mv "${TMP}.out" "$TMP"
      echo -e "${GREEN}[OK]${NC} Added statusLine config"
      CHANGED=true
    else
      echo -e "${YELLOW}[SKIP]${NC} statusLine already configured"
    fi

    if [ "$CHANGED" = true ]; then
      mv "$TMP" "$SETTINGS"
    else
      rm -f "$TMP"
    fi
  else
    echo -e "${YELLOW}[WARN]${NC} jq not found — cannot merge settings automatically"
    echo "  Add these manually to ${SETTINGS}:"
    echo '    "permissions": { "defaultMode": "acceptEdits" }'
    echo '    "statusLine": { "type": "command", "command": "~/.claude/statusline.sh", "padding": 1 }'
  fi
else
  # Create minimal settings.json with both defaults
  cat > "$SETTINGS" << 'SETTINGS_JSON'
{
  "permissions": {
    "defaultMode": "acceptEdits"
  },
  "statusLine": {
    "type": "command",
    "command": "~/.claude/statusline.sh",
    "padding": 1
  }
}
SETTINGS_JSON
  echo -e "${GREEN}[OK]${NC} Created ${SETTINGS} with defaults"
fi

echo ""
echo "Defaults configured:"
echo "  - Accept Edits mode enabled"
echo "  - Status line installed"
echo "  Takes effect on next Claude Code session."
