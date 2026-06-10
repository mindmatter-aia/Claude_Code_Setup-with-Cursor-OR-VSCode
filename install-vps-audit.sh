#!/usr/bin/env bash
# install-vps-audit.sh — Install & enable the monthly VPS security audit as an
# OS-native scheduled job:
#   - Linux / WSL2 : systemd user timer  (~/.config/systemd/user/vps-security-audit.{service,timer})
#   - macOS        : launchd LaunchAgent (~/Library/LaunchAgents/com.patriotagentic.vps-security-audit.plist)
# Idempotent. Safe to re-run. Skips cleanly if the audit script isn't present yet.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
source "${SCRIPT_DIR}/lib/platform.sh"

AUDIT_SCRIPT="${HOME}/.claude/scripts/vps-security-audit.sh"
PLATFORM="$(detect_platform)"
LABEL="com.patriotagentic.vps-security-audit"

echo ""
echo "── Monthly VPS security audit — scheduled job (${PLATFORM}) ──"

if [ ! -f "$AUDIT_SCRIPT" ]; then
  warn "VPS audit script not found at ${AUDIT_SCRIPT}"
  info "Import your ~/.claude config first (it ships the script), then re-run:"
  info "  bash install-vps-audit.sh"
  exit 0
fi
# Reports/log directory must exist for the job's redirect/StandardOutPath.
mkdir -p "${HOME}/.claude/security-reviews"

case "$PLATFORM" in
  linux|wsl2)
    UNIT_DIR="${HOME}/.config/systemd/user"
    mkdir -p "$UNIT_DIR"
    cp "${SCRIPT_DIR}/templates/vps-security-audit.service" "${UNIT_DIR}/vps-security-audit.service"
    cp "${SCRIPT_DIR}/templates/vps-security-audit.timer"   "${UNIT_DIR}/vps-security-audit.timer"
    systemctl --user daemon-reload

    # Keep the user manager (and thus the timer) alive across logout/reboot.
    if loginctl enable-linger "$USER" >/dev/null 2>&1; then
      log "Linger enabled for ${USER}"
    else
      warn "Could not enable linger automatically."
      info "If the timer stops after logout, run: sudo loginctl enable-linger ${USER}"
    fi

    # Enable the TIMER (not the service); the timer pulls in the oneshot service.
    systemctl --user enable --now vps-security-audit.timer
    if systemctl --user is-active --quiet vps-security-audit.timer; then
      log "vps-security-audit.timer is active (systemd user)."
      info "Next run: $(systemctl --user list-timers vps-security-audit.timer --no-legend 2>/dev/null | awk '{print $1, $2, $3}')"
    else
      err "vps-security-audit.timer did not start. Inspect: systemctl --user status vps-security-audit.timer"
    fi
    ;;

  macos)
    AGENT_DIR="${HOME}/Library/LaunchAgents"
    PLIST="${AGENT_DIR}/${LABEL}.plist"
    mkdir -p "$AGENT_DIR"
    sed "s|__HOME__|${HOME}|g" "${SCRIPT_DIR}/templates/vps-security-audit.plist.template" > "$PLIST"

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
      log "${LABEL} is registered with launchd (runs the 1st of each month)."
    fi
    ;;

  *)
    warn "Unknown platform '${PLATFORM}' — cannot install a scheduled job automatically."
    info "Run the audit manually when needed: bash ${AUDIT_SCRIPT}"
    exit 0
    ;;
esac

info "Run the audit on demand any time with: bash ${AUDIT_SCRIPT}"
