#!/usr/bin/env bash
# generate-mcp-json.sh — Generate .mcp.json with correct pnpm global paths
# Idempotent: overwrites .mcp.json each time
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

TEMPLATE="${SCRIPT_DIR}/templates/mcp.json.template"
OUTPUT="${PROJECT_DIR}/.mcp.json"

section_header "Generating .mcp.json"

require_command pnpm "Run install-tools.sh first." || exit 1

PNPM_GLOBAL="$(pnpm root -g)"

if [ ! -f "$TEMPLATE" ]; then
  err "Template not found: $TEMPLATE"
  exit 1
fi

# Verify at least one MCP package is installed
if [ ! -d "${PNPM_GLOBAL}/@modelcontextprotocol/server-memory" ]; then
  err "MCP packages not found at ${PNPM_GLOBAL}"
  echo "Run install-mcp-packages.sh first."
  exit 1
fi

SAFE_PNPM="$(escape_sed "$PNPM_GLOBAL")"
sed "s|__PNPM_GLOBAL__|${SAFE_PNPM}|g" "$TEMPLATE" > "$OUTPUT"

log "Generated: ${OUTPUT}"
info "pnpm global: ${PNPM_GLOBAL}"
echo ""
echo "Next: bash generate-workspace.sh"
