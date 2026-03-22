#!/usr/bin/env bash
# configure-directories.sh — Create workspace directory and scan for existing projects
# Idempotent: mkdir -p is inherently safe
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config
validate_config

DISCOVERED="${SCRIPT_DIR}/.discovered-projects"

section_header "Creating Directory Structure"

# Create projects root
mkdir -p "$PROJECTS_ROOT"
log "Projects root: ${PROJECTS_ROOT}"

# Scan for existing git repos (maxdepth 2, portable across GNU/BSD find)
echo ""
echo "── Scanning for existing projects ──"
PROJECT_LIST="$(find "$PROJECTS_ROOT" -maxdepth 2 -name ".git" -type d 2>/dev/null | sed 's|/\.git$||' | sort)"

if [ -n "$PROJECT_LIST" ]; then
  echo "$PROJECT_LIST" > "$DISCOVERED"
  PROJECT_COUNT="$(echo "$PROJECT_LIST" | wc -l)"
  log "Found ${PROJECT_COUNT} project(s):"
  echo ""
  while IFS= read -r project; do
    info "$(basename "$project")/ — ${project}"
  done <<< "$PROJECT_LIST"
else
  echo "" > "$DISCOVERED"
  info "No existing projects found in ${PROJECTS_ROOT}"
  info "Clone repos into ${PROJECTS_ROOT}/ and re-run to discover them."
fi

echo ""
echo "Project list: ${DISCOVERED}"
echo "Next: bash generate-mcp-json.sh"
