#!/usr/bin/env bash
# install-cl-observer.sh — Install & enable the Continuous Learning v2 observer
# as an OS-native background service:
#   - Linux / WSL2 : systemd user unit  (~/.config/systemd/user/cl-observer.service)
#   - macOS        : launchd LaunchAgent (~/Library/LaunchAgents/com.patriotagentic.cl-observer.plist)
# Idempotent. Safe to re-run. Skips cleanly if the CL-v2 skill isn't present yet.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"

SKILL_DIR="${HOME}/.claude/skills/continuous-learning-v2"
OBSERVER="${SKILL_DIR}/agents/start-observer.sh"
PLATFORM="$(detect_platform)"
LABEL="com.patriotagentic.cl-observer"

echo ""
echo "── Continuous Learning v2 — observer service (${PLATFORM}) ──"

if [ ! -x "$OBSERVER" ]; then
  warn "CL-v2 skill not found at ${SKILL_DIR}"
  info "Import your ~/.claude config first (it ships the skill), then re-run:"
  info "  bash install-cl-observer.sh"
  exit 0
fi

case "$PLATFORM" in
  linux|wsl2)
    UNIT_DIR="${HOME}/.config/systemd/user"
    mkdir -p "$UNIT_DIR"
    cp "${SCRIPT_DIR}/templates/cl-observer.service" "${UNIT_DIR}/cl-observer.service"
    systemctl --user daemon-reload

    # Keep the user manager (and thus the observer) alive across logout/reboot.
    if loginctl enable-linger "$USER" >/dev/null 2>&1; then
      log "Linger enabled for ${USER}"
    else
      warn "Could not enable linger automatically."
      info "If the observer stops after logout, run: sudo loginctl enable-linger ${USER}"
    fi

    systemctl --user enable --now cl-observer.service
    if systemctl --user is-active --quiet cl-observer.service; then
      log "cl-observer.service is active (systemd user)."
    else
      err "cl-observer.service did not start. Inspect: systemctl --user status cl-observer.service"
    fi
    ;;

  macos)
    AGENT_DIR="${HOME}/Library/LaunchAgents"
    PLIST="${AGENT_DIR}/${LABEL}.plist"
    mkdir -p "$AGENT_DIR" "${HOME}/.claude/homunculus"
    sed "s|__HOME__|${HOME}|g" "${SCRIPT_DIR}/templates/cl-observer.plist.template" > "$PLIST"

    # Reload cleanly if already registered.
    launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
    if launchctl bootstrap "gui/$(id -u)" "$PLIST" >/dev/null 2>&1; then
      launchctl enable "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
      log "Loaded launchd agent ${LABEL}."
    elif launchctl load -w "$PLIST" >/dev/null 2>&1; then
      log "Loaded launchd agent ${LABEL} (legacy load)."
    else
      err "Failed to load ${LABEL}. Try: launchctl bootstrap gui/$(id -u) ${PLIST}"
    fi
    if launchctl list 2>/dev/null | grep -q "$LABEL"; then
      log "${LABEL} is registered with launchd."
    fi
    ;;

  *)
    warn "Unknown platform '${PLATFORM}' — cannot install a background service automatically."
    info "Run the loop manually when working: bash ${OBSERVER} start"
    exit 0
    ;;
esac

info "Backlog of pending observations can be cleared now with:"
info "  bash ${OBSERVER} bootstrap"
