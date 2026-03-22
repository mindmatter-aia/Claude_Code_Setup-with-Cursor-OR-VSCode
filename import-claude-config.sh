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

if [ -d "${HOME}/.claude" ]; then
  if [[ "$REPLACE_MODE" == "true" ]]; then
    # Full overwrite: back up existing, then extract
    BACKUP="${HOME}/.claude.backup-$(date +%Y%m%d-%H%M%S)"
    warn "Replace mode: backing up existing ~/.claude/ to ${BACKUP}"
    mv "${HOME}/.claude" "$BACKUP"
    # Extract directly
    echo "Extracting ${TARBALL}..."
    tar xzf "$TARBALL" -C "${HOME}/"
  else
    # Merge mode: extract to temp dir, rsync --ignore-existing
    log "Merge mode: preserving existing ~/.claude/ files"
    TMPDIR="$(mktemp -d)"
    echo "Extracting to temp dir..."
    tar xzf "$TARBALL" -C "$TMPDIR/"
    echo "Merging new files (existing files are preserved)..."
    rsync --ignore-existing -a "${TMPDIR}/.claude/" "${HOME}/.claude/"
    rm -rf "$TMPDIR"
  fi
else
  # No existing config — extract directly
  echo "Extracting ${TARBALL}..."
  tar xzf "$TARBALL" -C "${HOME}/"
fi

# Patch hardcoded paths from old user to current user
OLD_HOME=""
if [ -f "${HOME}/.claude/settings.json" ]; then
  OLD_HOME=$(grep -oP '/home/[^/]+' "${HOME}/.claude/settings.json" | head -1 || true)
fi

if [ -n "$OLD_HOME" ] && [ "$OLD_HOME" != "${HOME}" ]; then
  echo "Patching paths: ${OLD_HOME} -> ${HOME}"
  find "${HOME}/.claude" -name '*.json' -o -name '*.md' | while read -r file; do
    if grep -q "$OLD_HOME" "$file" 2>/dev/null; then
      sed -i "s|${OLD_HOME}|${HOME}|g" "$file"
    fi
  done
  log "Paths patched"
else
  log "No path patching needed"
fi

# Set executable permissions on scripts
find "${HOME}/.claude" -name '*.sh' -exec chmod +x {} \;
find "${HOME}/.claude" -name '*.js' -exec chmod +x {} \;

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
