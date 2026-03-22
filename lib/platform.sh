#!/usr/bin/env bash
# lib/platform.sh — Platform, IDE, package manager, and shell detection
# Source this from scripts that need platform-aware behavior

# ── Platform detection ──────────────────────────────────────────
# Returns: macos | linux | wsl2 | unknown
detect_platform() {
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "wsl2"
  elif [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  elif [[ "$(uname -s)" == "Linux" ]]; then
    echo "linux"
  else
    echo "unknown"
  fi
}

# ── Shell detection ─────────────────────────────────────────────
# Returns: bash | zsh
detect_shell() {
  local user_shell
  user_shell="$(basename "${SHELL:-/bin/bash}")"
  if [[ "$user_shell" == "zsh" ]]; then
    echo "zsh"
  else
    echo "bash"
  fi
}

# ── Shell RC file ───────────────────────────────────────────────
# Returns: ~/.bashrc or ~/.zshrc
get_shell_rc() {
  local shell_type
  shell_type="$(detect_shell)"
  if [[ "$shell_type" == "zsh" ]]; then
    echo "${HOME}/.zshrc"
  else
    echo "${HOME}/.bashrc"
  fi
}

# ── Package manager ─────────────────────────────────────────────
# Returns: brew | apt
get_package_manager() {
  local platform
  platform="$(detect_platform)"
  if [[ "$platform" == "macos" ]]; then
    echo "brew"
  else
    echo "apt"
  fi
}

# ── IDE detection ───────────────────────────────────────────────
# Returns: space-separated list of found IDEs (vscode cursor)
detect_ides() {
  local platform found=""
  platform="$(detect_platform)"

  case "$platform" in
    macos)
      # Check app bundles first, then CLI
      if [ -d "/Applications/Visual Studio Code.app" ] || command -v code &> /dev/null; then
        found="vscode"
      fi
      if [ -d "/Applications/Cursor.app" ] || command -v cursor &> /dev/null; then
        found="${found:+$found }cursor"
      fi
      # Hint if app exists but CLI not in PATH
      if [ -d "/Applications/Visual Studio Code.app" ] && ! command -v code &> /dev/null; then
        echo "hint: VS Code app found but 'code' CLI not in PATH. Run 'Shell Command: Install code command in PATH' from the VS Code command palette." >&2
      fi
      if [ -d "/Applications/Cursor.app" ] && ! command -v cursor &> /dev/null; then
        echo "hint: Cursor app found but 'cursor' CLI not in PATH. Run 'Shell Command: Install cursor command in PATH' from the Cursor command palette." >&2
      fi
      ;;
    wsl2)
      # Check Windows-side installations
      local win_base=""
      if [ -d /mnt/c/Users ]; then
        for dir in /mnt/c/Users/*/; do
          local uname
          uname=$(basename "$dir")
          if [ "$uname" != "Public" ] && [ "$uname" != "Default" ] && \
             [ "$uname" != "Default User" ] && [ "$uname" != "All Users" ]; then
            if [ -d "${dir}AppData/Local/Programs/Microsoft VS Code" ] || \
               [ -d "${dir}AppData/Local/Programs/cursor" ]; then
              win_base="${dir}AppData/Local/Programs"
              break
            fi
          fi
        done
      fi
      if [ -n "$win_base" ]; then
        if [ -d "${win_base}/Microsoft VS Code" ]; then
          found="vscode"
        fi
        if [ -d "${win_base}/cursor" ]; then
          found="${found:+$found }cursor"
        fi
      fi
      # Also check Linux-side CLI
      if [ -z "$found" ]; then
        command -v code &> /dev/null && found="vscode"
        command -v cursor &> /dev/null && found="${found:+$found }cursor"
      fi
      ;;
    linux)
      command -v code &> /dev/null && found="vscode"
      command -v cursor &> /dev/null && found="${found:+$found }cursor"
      ;;
  esac

  echo "$found"
}

# ── IDE CLI command path ────────────────────────────────────────
# Usage: get_ide_cli <ide>  (ide = vscode | cursor)
# Returns: the full CLI command for the given IDE on current platform
get_ide_cli() {
  local ide="$1"
  local platform
  platform="$(detect_platform)"

  case "$platform" in
    wsl2)
      local win_base=""
      if [ -d /mnt/c/Users ]; then
        for dir in /mnt/c/Users/*/; do
          local uname
          uname=$(basename "$dir")
          if [ "$uname" != "Public" ] && [ "$uname" != "Default" ] && \
             [ "$uname" != "Default User" ] && [ "$uname" != "All Users" ]; then
            win_base="${dir}AppData/Local/Programs"
            break
          fi
        done
      fi
      if [[ "$ide" == "vscode" ]] && [ -d "${win_base}/Microsoft VS Code" ]; then
        echo "\"${win_base}/Microsoft VS Code/bin/code\""
      elif [[ "$ide" == "cursor" ]] && [ -d "${win_base}/cursor" ]; then
        echo "\"${win_base}/cursor/resources/app/bin/cursor\""
      fi
      ;;
    macos|linux)
      if [[ "$ide" == "vscode" ]]; then
        echo "code"
      elif [[ "$ide" == "cursor" ]]; then
        echo "cursor"
      fi
      ;;
  esac
}

# ── SSH agent shell block ───────────────────────────────────────
# macOS uses Keychain; Linux/WSL2 uses manual ssh-agent start
get_ssh_agent_block() {
  local platform
  platform="$(detect_platform)"

  if [[ "$platform" == "macos" ]]; then
    # macOS: Keychain handles ssh-agent, just ensure key is added
    cat << 'BLOCK'
# macOS Keychain handles ssh-agent automatically
ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null
BLOCK
  else
    cat << 'BLOCK'
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null 2>&1
  ssh-add ~/.ssh/id_ed25519 2>/dev/null
fi
BLOCK
  fi
}
