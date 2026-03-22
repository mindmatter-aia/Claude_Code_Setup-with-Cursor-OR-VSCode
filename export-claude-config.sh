#!/usr/bin/env bash
# export-claude-config.sh — Export ~/.claude/ for transfer to a new machine
# Creates a tarball in setup/export/ (gitignored)
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORT_DIR="${SCRIPT_DIR}/export"
DATE=$(date +%Y%m%d-%H%M%S)
TARBALL="${EXPORT_DIR}/claude-config-${DATE}.tar.gz"

echo "============================================"
echo "  Exporting ~/.claude/ Configuration"
echo "============================================"
echo ""

if [ ! -d "${HOME}/.claude" ]; then
  echo -e "${RED}[ERROR]${NC} ~/.claude/ directory not found"
  exit 1
fi

mkdir -p "$EXPORT_DIR"

# Export ~/.claude/ excluding machine-specific and large directories
tar czf "$TARBALL" \
  -C "${HOME}" \
  --exclude='.claude/.git' \
  --exclude='.claude/*/.git' \
  --exclude='.claude/*/*/.git' \
  --exclude='.claude/sessions' \
  --exclude='.claude/cache' \
  --exclude='.claude/file-history' \
  --exclude='.claude/shell-snapshots' \
  --exclude='.claude/session-env' \
  --exclude='.claude/projects' \
  --exclude='.claude/ide' \
  --exclude='.claude/backups' \
  --exclude='.claude/settings.json.bak' \
  --exclude='.claude/skills/browse' \
  --exclude='.claude/skills/gstack' \
  --exclude='.claude/skills/gstack-upgrade' \
  --exclude='.claude/plugins' \
  --exclude='.claude/telemetry' \
  --exclude='.claude/history.jsonl' \
  --exclude='node_modules' \
  .claude/

SIZE=$(du -h "$TARBALL" | cut -f1)

echo -e "${GREEN}[OK]${NC} Exported to: ${TARBALL}"
echo "     Size: ${SIZE}"
echo ""
echo "Contents:"
tar tzf "$TARBALL" | head -30
TOTAL=$(tar tzf "$TARBALL" | wc -l)
echo "     ... (${TOTAL} total entries)"
echo ""
echo "Transfer this file to the new machine, then run:"
echo "  bash import-claude-config.sh ${TARBALL}"
