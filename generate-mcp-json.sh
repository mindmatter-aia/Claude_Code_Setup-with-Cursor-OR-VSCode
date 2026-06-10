#!/usr/bin/env bash
# generate-mcp-json.sh — Generate .mcp.json (servers launch via `npx -y`)
# Idempotent: overwrites .mcp.json each time
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

TEMPLATE="${SCRIPT_DIR}/templates/mcp.json.template"
OUTPUT="${PROJECT_DIR:-$PWD}/.mcp.json"

section_header "Generating .mcp.json"

if [ ! -f "$TEMPLATE" ]; then
  err "Template not found: $TEMPLATE"
  exit 1
fi

# Servers launch via `npx -y <pkg>` (resolved at runtime), so no global install
# path is baked in. This is robust across pnpm/npm versions and machines — the
# old `node <pnpm root -g>/pkg/...` form broke on pnpm 11's content-addressed
# global store (no resolvable node_modules under `pnpm root -g`).
# install-mcp-packages.sh can pre-warm the packages, but is not required.
cp "$TEMPLATE" "$OUTPUT"

log "Generated: ${OUTPUT}"
info "Servers use 'npx -y' (first launch fetches packages if not cached)."
echo ""
echo "Next: bash generate-workspace.sh"
