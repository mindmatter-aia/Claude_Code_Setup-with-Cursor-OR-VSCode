#!/usr/bin/env bash
# patch-project-settings.sh — Fix hardcoded paths in project-level .claude/settings.json
# The project settings.json has absolute paths to hook scripts
# This patches them for the current user and repo location
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

SETTINGS="${PROJECT_DIR}/.claude/settings.json"

section_header "Patching Project Settings"

if [ ! -f "$SETTINGS" ]; then
  err "Project settings not found: ${SETTINGS}"
  exit 1
fi

# Detect old path from the settings file (matches /home/<user>/<path> or /Users/<user>/<path>)
OLD_REPO_PATH=$(grep -oP '/(home|Users)/[^/]+/[^"]+' "$SETTINGS" | head -1 || true)
OLD_REPO_DIR="$(dirname "$(dirname "$OLD_REPO_PATH")")" 2>/dev/null || true

if [ -z "$OLD_REPO_PATH" ]; then
  log "No hardcoded paths found — nothing to patch"
  exit 0
fi

# Extract just the base project path (up to the project dir)
OLD_PROJECT_DIR="$(echo "$OLD_REPO_PATH" | grep -oP '^.+(?=/\.claude)' || echo "$OLD_REPO_PATH")"

if [ "$OLD_PROJECT_DIR" = "$PROJECT_DIR" ]; then
  log "Paths already match current location ($PROJECT_DIR)"
  exit 0
fi

warn "Patching: ${OLD_PROJECT_DIR} -> ${PROJECT_DIR}"
SAFE_OLD="$(escape_sed "$OLD_PROJECT_DIR")"
SAFE_NEW="$(escape_sed "$PROJECT_DIR")"
sed -i "s|${SAFE_OLD}|${SAFE_NEW}|g" "$SETTINGS"

log "Project settings patched"
echo ""
echo "Affected hooks that referenced absolute paths:"
grep -n "node ${PROJECT_DIR}" "$SETTINGS" | head -10 || true
echo ""
echo "NOTE: This changes a git-tracked file. Commit when ready."
