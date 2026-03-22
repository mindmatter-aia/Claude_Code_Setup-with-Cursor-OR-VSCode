#!/usr/bin/env bash
# install-mcp-packages.sh — Install MCP server packages globally via pnpm
# Idempotent: pnpm add -g is safe to re-run
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

section_header "Installing MCP Server Packages"

require_command pnpm "Run install-tools.sh first." || exit 1

# All available MCP server short names
ALL_SERVERS="memory,sequential-thinking,github,context7,n8n-workflow-builder,n8n-mcp"

echo "Configured servers: ${MCP_SERVERS}"
echo ""

# Install each configured server
while IFS='=' read -r short_name package; do
  echo "Installing ${short_name} (${package})..."
  pnpm add -g "$package"
  log "${short_name} installed"
done < <(get_mcp_packages)

# Report skipped servers
IFS=',' read -ra configured <<< "$MCP_SERVERS"
IFS=',' read -ra all <<< "$ALL_SERVERS"
for server in "${all[@]}"; do
  server="$(echo "$server" | xargs)"
  found=false
  for cfg in "${configured[@]}"; do
    cfg="$(echo "$cfg" | xargs)"
    if [[ "$cfg" == "$server" ]]; then
      found=true
      break
    fi
  done
  if [[ "$found" == "false" ]]; then
    skip "${server} (not in MCP_SERVERS config)"
  fi
done

echo ""
log "MCP packages installed"
echo ""
echo "Global pnpm root: $(pnpm root -g)"
echo ""
echo "Installed packages:"
pnpm list -g --depth=0 2>/dev/null | grep -E "@modelcontextprotocol|context7|n8n" || true
echo ""
echo "Next: bash configure-shell.sh"
