#!/usr/bin/env bash
# import-claude-config.sh — Import ~/.claude/ from an exported tarball
# Default: merge mode (preserves existing files). Use --replace for full overwrite.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

EXPORT_DIR="${SCRIPT_DIR}/export"
REPLACE_MODE=false

# Parse arguments
TARBALL=""
for arg in "$@"; do
  case "$arg" in
    --replace) REPLACE_MODE=true ;;
    *) TARBALL="$arg" ;;
  esac
done

# Find tarball: use argument, or latest in export/
if [ -z "$TARBALL" ]; then
  TARBALL=$(ls -t "${EXPORT_DIR}"/claude-config-*.tar.gz 2>/dev/null | head -1)
  if [ -z "$TARBALL" ]; then
    err "No tarball specified and none found in ${EXPORT_DIR}/"
    echo "Usage: bash import-claude-config.sh [--replace] <path-to-tarball>"
    exit 1
  fi
  info "Using latest: ${TARBALL}"
fi

if [ ! -f "$TARBALL" ]; then
  err "File not found: ${TARBALL}"
  exit 1
fi

section_header "Importing ~/.claude/ Configuration"

# ── Security: validate tarball contents before extraction ──
echo "Validating tarball contents..."
UNSAFE_ENTRIES="$(tar tzf "$TARBALL" 2>/dev/null | grep -vE '^\.?claude/' | grep -v '^\.$' | grep -v '^$' || true)"
if [ -n "$UNSAFE_ENTRIES" ]; then
  err "Tarball contains entries outside .claude/ — refusing to extract for safety:"
  echo "$UNSAFE_ENTRIES" | head -20
  exit 1
fi

# ── Always extract to temp dir first, then copy only .claude/ ──
SAFE_TMPDIR="$(mktemp -d "${HOME}/.claude-import.XXXXXX")"
echo "Extracting to secure temp dir..."
tar xzf "$TARBALL" -C "$SAFE_TMPDIR/"

# Verify .claude/ directory exists in the extracted content
EXTRACTED_CLAUDE=""
if [ -d "$SAFE_TMPDIR/.claude" ]; then
  EXTRACTED_CLAUDE="$SAFE_TMPDIR/.claude"
elif [ -d "$SAFE_TMPDIR/claude" ]; then
  EXTRACTED_CLAUDE="$SAFE_TMPDIR/claude"
else
  err "Tarball does not contain a .claude/ directory"
  rm -rf "$SAFE_TMPDIR"
  exit 1
fi

if [ -d "${HOME}/.claude" ]; then
  if [[ "$REPLACE_MODE" == "true" ]]; then
    BACKUP="${HOME}/.claude.backup-$(date +%Y%m%d-%H%M%S)"
    warn "Replace mode: backing up existing ~/.claude/ to ${BACKUP}"
    mv "${HOME}/.claude" "$BACKUP"
    mv "$EXTRACTED_CLAUDE" "${HOME}/.claude"
  else
    log "Merge mode: preserving existing ~/.claude/ files"
    rsync --ignore-existing -a "$EXTRACTED_CLAUDE/" "${HOME}/.claude/"
  fi
else
  mv "$EXTRACTED_CLAUDE" "${HOME}/.claude"
fi
rm -rf "$SAFE_TMPDIR"

# Patch hardcoded paths from old user to current user
OLD_HOME=""
if [ -f "${HOME}/.claude/settings.json" ]; then
  OLD_HOME=$(grep -oP '/home/[^/]+' "${HOME}/.claude/settings.json" | head -1 || true)
fi

if [ -n "$OLD_HOME" ] && [ "$OLD_HOME" != "${HOME}" ]; then
  echo "Patching paths: ${OLD_HOME} -> ${HOME}"
  SAFE_OLD="$(escape_sed "$OLD_HOME")"
  SAFE_NEW="$(escape_sed "$HOME")"
  find "${HOME}/.claude" -name '*.json' -o -name '*.md' | while read -r file; do
    if grep -q "$OLD_HOME" "$file" 2>/dev/null; then
      sed -i "s|${SAFE_OLD}|${SAFE_NEW}|g" "$file"
    fi
  done
  log "Paths patched"
else
  log "No path patching needed"
fi

# Set executable permissions on known script directories only
for dir in scripts scripts/hooks; do
  if [ -d "${HOME}/.claude/${dir}" ]; then
    find "${HOME}/.claude/${dir}" \( -name '*.sh' -o -name '*.js' \) -exec chmod +x {} \;
  fi
done
# Known top-level scripts
[ -f "${HOME}/.claude/statusline.sh" ] && chmod +x "${HOME}/.claude/statusline.sh"

# Count what was imported
AGENTS=$(ls "${HOME}/.claude/agents/"*.md 2>/dev/null | wc -l)
COMMANDS=$(ls "${HOME}/.claude/commands/"*.md 2>/dev/null | wc -l)
RULES=$(ls "${HOME}/.claude/rules/"*.md 2>/dev/null | wc -l)
SKILLS=$(ls -d "${HOME}/.claude/skills/"*/ 2>/dev/null | wc -l)

echo ""
log "Import complete:"
echo "     Agents:   ${AGENTS}"
echo "     Commands: ${COMMANDS}"
echo "     Rules:    ${RULES}"
echo "     Skills:   ${SKILLS}"
if [[ "$REPLACE_MODE" == "false" ]] && [ -d "${HOME}/.claude" ]; then
  info "Mode: merge (existing files preserved)"
else
  info "Mode: replace"
fi
echo ""
echo "Next: bash patch-project-settings.sh"
