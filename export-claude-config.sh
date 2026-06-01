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
  --exclude='.claude/ide' \
  --exclude='.claude/backups' \
  --exclude='.claude/settings.json.bak' \
  --exclude='.claude/settings.local.json' \
  --exclude='.claude/CLAUDE.local.md' \
  --exclude='.claude/skills/browse' \
  --exclude='.claude/skills/gstack' \
  --exclude='.claude/skills/gstack-upgrade' \
  --exclude='.claude/plugins' \
  --exclude='.claude/telemetry' \
  --exclude='.claude/history.jsonl' \
  --exclude='node_modules' \
  `# projects/: keep auto-memory (projects/*/memory + MEMORY.md), drop session` \
  `# transcripts and UUID-named session dirs. 'memory' has no hyphens, so the` \
  `# 5-group UUID glob below spares it while pruning 327d2266-df08-... entries.` \
  --exclude='.claude/projects/*/*-*-*-*-*' \
  --exclude='.claude/projects/*/*.jsonl' \
  `# CL-v2: keep instincts + config + evolved, drop machine-specific runtime` \
  --exclude='.claude/homunculus/observations.jsonl' \
  --exclude='.claude/homunculus/observations.archive' \
  --exclude='.claude/homunculus/.observer.pid' \
  --exclude='.claude/homunculus/observer.log' \
  --exclude='.claude/homunculus/observer-cost.log' \
  --exclude='.claude/homunculus/launchd-observer.log' \
  --exclude='.claude/homunculus/.analysis-summary.json' \
  --exclude='.claude/homunculus/.domain-summary.md' \
  --exclude='.claude/homunculus/.observer-prompt.tmp' \
  --exclude='.claude/homunculus/.claude-cycle.log' \
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
