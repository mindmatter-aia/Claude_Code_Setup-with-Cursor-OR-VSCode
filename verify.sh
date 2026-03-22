#!/usr/bin/env bash
# verify.sh — Post-setup verification checklist (cross-platform)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

PLATFORM="$(detect_platform)"
RC_FILE="$(get_shell_rc)"

PASS=0
FAIL=0
WARN=0

# check/warn_check: pass the command as arguments (no eval)
check() {
  local name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo -e "  ${CLR_GREEN}PASS${CLR_RESET}  $name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${CLR_RED}FAIL${CLR_RESET}  $name"
    FAIL=$((FAIL + 1))
  fi
}

warn_check() {
  local name="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    echo -e "  ${CLR_GREEN}PASS${CLR_RESET}  $name"
    PASS=$((PASS + 1))
  else
    echo -e "  ${CLR_YELLOW}WARN${CLR_RESET}  $name"
    WARN=$((WARN + 1))
  fi
}

section_header "Setup Verification (${PLATFORM})"

# ── Tools ──
echo "── Tools ──"
check "nvm"           test -s "${HOME}/.nvm/nvm.sh"
check "node"          command -v node
check "npm"           command -v npm
check "pnpm"          command -v pnpm

if [[ "${INSTALL_BUN}" == "true" ]]; then
  warn_check "bun"    command -v bun
fi

check "gh"            command -v gh

if [[ "${INSTALL_DOPPLER}" == "true" ]]; then
  check "doppler"     command -v doppler
fi

check "claude"        command -v claude
check "git"           command -v git
check "jq"            command -v jq
check "rsync"         command -v rsync

echo ""
echo "── Versions ──"
echo "     node:    $(node --version 2>/dev/null || echo 'N/A')"
echo "     npm:     $(npm --version 2>/dev/null || echo 'N/A')"
echo "     pnpm:    $(pnpm --version 2>/dev/null || echo 'N/A')"
if [[ "${INSTALL_BUN}" == "true" ]]; then
  echo "     bun:     $(bun --version 2>/dev/null || echo 'N/A')"
fi
echo "     gh:      $(gh --version 2>/dev/null | head -1 || echo 'N/A')"
if [[ "${INSTALL_DOPPLER}" == "true" ]]; then
  echo "     doppler: $(doppler --version 2>/dev/null || echo 'N/A')"
fi

echo ""
echo "── MCP Packages ──"
PNPM_GLOBAL="$(pnpm root -g 2>/dev/null || echo '/dev/null')"
IFS=',' read -ra configured_servers <<< "$MCP_SERVERS"
for server in "${configured_servers[@]}"; do
  server="$(echo "$server" | xargs)"
  case "$server" in
    memory)               check "server-memory"              test -d "${PNPM_GLOBAL}/@modelcontextprotocol/server-memory" ;;
    sequential-thinking)  check "server-sequential-thinking" test -d "${PNPM_GLOBAL}/@modelcontextprotocol/server-sequential-thinking" ;;
    github)               check "server-github"              test -d "${PNPM_GLOBAL}/@modelcontextprotocol/server-github" ;;
    context7)             check "context7-mcp"               test -d "${PNPM_GLOBAL}/@upstash/context7-mcp" ;;
    n8n-workflow-builder) check "n8n-workflow-builder"       test -d "${PNPM_GLOBAL}/@makafeli/n8n-workflow-builder" ;;
    n8n-mcp)              check "n8n-mcp"                    test -d "${PNPM_GLOBAL}/n8n-mcp" ;;
  esac
done

echo ""
echo "── Claude Code Config ──"
check "~/.claude/ exists"          test -d "${HOME}/.claude"
check "agents/"                    test -d "${HOME}/.claude/agents"
check "commands/"                  test -d "${HOME}/.claude/commands"
check "rules/"                     test -d "${HOME}/.claude/rules"
check "skills/"                    test -d "${HOME}/.claude/skills"
check "settings.json"              test -f "${HOME}/.claude/settings.json"

AGENTS=$(ls "${HOME}/.claude/agents/"*.md 2>/dev/null | wc -l)
COMMANDS=$(ls "${HOME}/.claude/commands/"*.md 2>/dev/null | wc -l)
RULES=$(ls "${HOME}/.claude/rules/"*.md 2>/dev/null | wc -l)
echo "     agents:   ${AGENTS} files"
echo "     commands: ${COMMANDS} files"
echo "     rules:    ${RULES} files"

echo ""
echo "── Project Files ──"
check ".mcp.json"                  test -f "${PROJECT_DIR}/.mcp.json"
warn_check ".env"                  test -f "${PROJECT_DIR}/.env"
check "CLAUDE.md"                  test -f "${PROJECT_DIR}/CLAUDE.md"

# Verify .mcp.json paths resolve
if [ -f "${PROJECT_DIR}/.mcp.json" ] && command -v jq &> /dev/null; then
  MEMORY_PATH=$(jq -r '.mcpServers.memory.args[0]' "${PROJECT_DIR}/.mcp.json" 2>/dev/null)
  if [ -n "$MEMORY_PATH" ] && [ "$MEMORY_PATH" != "null" ]; then
    check ".mcp.json paths resolve"  test -f "$MEMORY_PATH"
  fi
fi

# Check for workspace file (any .code-workspace)
WORKSPACE_FILE=$(ls "${PROJECT_DIR}"/*.code-workspace 2>/dev/null | head -1)
if [ -n "$WORKSPACE_FILE" ]; then
  check "workspace file" test -f "$WORKSPACE_FILE"
else
  echo -e "  ${CLR_YELLOW}WARN${CLR_RESET}  No .code-workspace file found"
  WARN=$((WARN + 1))
fi

echo ""
echo "── Directory Structure ──"
check "Projects root (${PROJECTS_ROOT})"  test -d "${PROJECTS_ROOT}"

echo ""
echo "── Authentication ──"
warn_check "SSH key exists"        test -f "${HOME}/.ssh/id_ed25519"
warn_check "GitHub CLI auth"       gh auth status
if [[ "${INSTALL_DOPPLER}" == "true" ]]; then
  warn_check "Doppler auth"       doppler configs
fi

echo ""
echo "── IDE ──"
IDES="$(detect_ides)"
if [ -n "$IDES" ]; then
  for ide in $IDES; do
    echo -e "  ${CLR_GREEN}PASS${CLR_RESET}  ${ide}"
    PASS=$((PASS + 1))
  done
else
  echo -e "  ${CLR_YELLOW}WARN${CLR_RESET}  No IDE detected"
  WARN=$((WARN + 1))
fi

echo ""
echo "── Shell RC Blocks ($(basename "$RC_FILE")) ──"
check "nvm block"       grep -q '>>> dev-env:nvm >>>' "$RC_FILE"
check "pnpm block"      grep -q '>>> dev-env:pnpm >>>' "$RC_FILE"
check "claude block"    grep -q '>>> dev-env:claude >>>' "$RC_FILE"
check "editor block"    grep -q '>>> dev-env:editor >>>' "$RC_FILE"
check "ssh-agent block" grep -q '>>> dev-env:ssh-agent >>>' "$RC_FILE"

echo ""
echo "============================================"
echo -e "  Results: ${CLR_GREEN}${PASS} passed${CLR_RESET}, ${CLR_RED}${FAIL} failed${CLR_RESET}, ${CLR_YELLOW}${WARN} warnings${CLR_RESET}"
echo "============================================"

if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
