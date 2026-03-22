#!/usr/bin/env bash
# lib/common.sh — Shared colors, logging, and shell-block helpers
# Source this from all setup scripts

# ── Colors ──────────────────────────────────────────────────────
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_RED='\033[0;31m'
CLR_RESET='\033[0m'
CLR_BOLD='\033[1m'
CLR_DIM='\033[2m'

# ── Logging ─────────────────────────────────────────────────────
log()  { echo -e "${CLR_GREEN}[OK]${CLR_RESET} $1"; }
skip() { echo -e "${CLR_YELLOW}[SKIP]${CLR_RESET} $1"; }
info() { echo -e "     $1"; }
warn() { echo -e "${CLR_YELLOW}[WARN]${CLR_RESET} $1"; }
err()  { echo -e "${CLR_RED}[ERROR]${CLR_RESET} $1"; }

# ── Section header ──────────────────────────────────────────────
section_header() {
  echo ""
  echo "============================================"
  echo "  $1"
  echo "============================================"
  echo ""
}

# ── Idempotent shell block insertion ────────────────────────────
# Usage: add_shell_block <rc_file> <name> <content>
# Inserts a marker-delimited block into a shell RC file.
# Skips if the block already exists.
add_shell_block() {
  local rc_file="$1"
  local name="$2"
  local content="$3"
  local marker="# >>> dev-env:${name} >>>"
  local end_marker="# <<< dev-env:${name} <<<"

  if grep -qF "$marker" "$rc_file" 2>/dev/null; then
    skip "$name (already configured)"
    return
  fi

  {
    echo ""
    echo "$marker"
    echo "$content"
    echo "$end_marker"
  } >> "$rc_file"
  log "$name added to $(basename "$rc_file")"
}

# ── Require a command or print install hint ─────────────────────
# Usage: require_command <cmd> <hint>
require_command() {
  local cmd="$1"
  local hint="$2"
  if ! command -v "$cmd" &> /dev/null; then
    err "$cmd not found. $hint"
    return 1
  fi
}
