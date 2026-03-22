#!/usr/bin/env bash
# generate-workspace.sh — Generate IDE workspace file (VS Code / Cursor)
# Both IDEs use the same .code-workspace format
# Idempotent: overwrites workspace file each time
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"
source "${SCRIPT_DIR}/lib/config.sh"
load_config

WORKSPACE_NAME="$(basename "$PROJECT_DIR")"
OUTPUT="${PROJECT_DIR}/${WORKSPACE_NAME}.code-workspace"
DISCOVERED="${SCRIPT_DIR}/.discovered-projects"
PLATFORM="$(detect_platform)"

section_header "Generating IDE Workspace"

# Build folders array — always include the project dir as "."
FOLDERS="    {
      \"name\": \"${WORKSPACE_NAME}\",
      \"path\": \".\"
    }"

# Get discovered projects (from file or fresh scan)
PROJECT_LIST=""
if [ -f "$DISCOVERED" ] && [ -s "$DISCOVERED" ]; then
  PROJECT_LIST="$(cat "$DISCOVERED")"
elif [ -d "$PROJECTS_ROOT" ]; then
  PROJECT_LIST="$(find "$PROJECTS_ROOT" -maxdepth 2 -name ".git" -type d 2>/dev/null | sed 's|/\.git$||' | sort)"
fi

# Add each discovered project with correct relative path
if [ -n "$PROJECT_LIST" ]; then
  while IFS= read -r project; do
    [ -z "$project" ] && continue
    project_name="$(basename "$project")"
    # Skip the project dir itself (already included)
    if [[ "$project" == "$PROJECT_DIR" ]]; then
      continue
    fi
    # Compute relative path from project dir (pass as args, not string interpolation)
    rel_path="$(python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$project" "$PROJECT_DIR" 2>/dev/null || echo "$project")"
    # Escape JSON special characters in names/paths
    safe_name="$(printf '%s' "$project_name" | sed 's/["\\]/\\&/g')"
    safe_path="$(printf '%s' "$rel_path" | sed 's/["\\]/\\&/g')"
    FOLDERS="${FOLDERS},
    {
      \"name\": \"${safe_name}\",
      \"path\": \"${safe_path}\"
    }"
  done <<< "$PROJECT_LIST"
fi

# Platform-aware settings
SETTINGS=""
case "$PLATFORM" in
  wsl2)
    SETTINGS='"terminal.integrated.defaultProfile.linux": "bash",
    "remote.WSL.fileWatcher.polling": false'
    ;;
  macos)
    SETTINGS='"terminal.integrated.defaultProfile.osx": "zsh"'
    ;;
  linux)
    SETTINGS='"terminal.integrated.defaultProfile.linux": "bash"'
    ;;
esac

cat > "$OUTPUT" << EOF
{
  "folders": [
${FOLDERS}
  ],
  "settings": {
    ${SETTINGS}
  }
}
EOF

log "Generated: ${OUTPUT}"
echo ""
echo "Open with VS Code:  code ${OUTPUT}"
echo "Open with Cursor:   cursor ${OUTPUT}"
