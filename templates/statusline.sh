#!/bin/bash
# Claude Code status line — shows context, cost, model, cwd, git branch
input=$(cat)

# ── Extract fields ──
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
CWD=$(echo "$input" | jq -r '.workspace.current_dir // "?"')
PROJECT=$(echo "$input" | jq -r '.workspace.project_dir // "?"')
USED_PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' | cut -d. -f1)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DURATION_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
LINES_ADD=$(echo "$input" | jq -r '.cost.total_lines_added // 0')
LINES_DEL=$(echo "$input" | jq -r '.cost.total_lines_removed // 0')
AGENT=$(echo "$input" | jq -r '.agent.name // empty')
WORKTREE=$(echo "$input" | jq -r '.worktree.name // empty')
WT_BRANCH=$(echo "$input" | jq -r '.worktree.branch // empty')

# Rate limits (Pro/Max only)
FIVE_H=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')

# ── Colors ──
C='\033[36m'    # cyan
G='\033[32m'    # green
Y='\033[33m'    # yellow
R='\033[31m'    # red
D='\033[90m'    # dim
B='\033[1m'     # bold
N='\033[0m'     # reset

# ── Context bar (color by usage) ──
if [ "$USED_PCT" -ge 85 ]; then CTX_COLOR="$R"
elif [ "$USED_PCT" -ge 65 ]; then CTX_COLOR="$Y"
else CTX_COLOR="$G"; fi

FILLED=$((USED_PCT / 5))
EMPTY=$((20 - FILLED))
[ "$FILLED" -gt 20 ] && FILLED=20 && EMPTY=0
printf -v FILL "%${FILLED}s"
printf -v PAD "%${EMPTY}s"
BAR="${FILL// /▓}${PAD// /░}"

# ── Git branch (from cwd) ──
BRANCH=""
if [ -d "$CWD" ]; then
  BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null)
fi

# ── Shorten cwd ──
SHORT_CWD="${CWD/#$HOME/~}"

# ── Format duration ──
MINS=$((DURATION_MS / 60000))
SECS=$(((DURATION_MS % 60000) / 1000))
if [ "$MINS" -gt 0 ]; then
  TIME="${MINS}m${SECS}s"
else
  TIME="${SECS}s"
fi

# ── Format cost ──
COST_FMT=$(printf '$%.2f' "$COST")

# ── Line 1: Context bar + model + cost + time ──
LINE1="${CTX_COLOR}${BAR}${N} ${B}${USED_PCT}%${N}"
LINE1="${LINE1}  ${D}|${N}  ${C}${MODEL}${N}"
LINE1="${LINE1}  ${D}|${N}  ${COST_FMT}"
LINE1="${LINE1}  ${D}|${N}  ${TIME}"

# Add rate limit if available
if [ -n "$FIVE_H" ]; then
  FIVE_H_INT=$(printf '%.0f' "$FIVE_H")
  if [ "$FIVE_H_INT" -ge 80 ]; then RL_COLOR="$R"
  elif [ "$FIVE_H_INT" -ge 50 ]; then RL_COLOR="$Y"
  else RL_COLOR="$G"; fi
  LINE1="${LINE1}  ${D}|${N}  ${RL_COLOR}rate:${FIVE_H_INT}%${N}"
fi

# ── Line 2: cwd + branch + lines changed + agent/worktree ──
LINE2="${D}${SHORT_CWD}${N}"
if [ -n "$BRANCH" ]; then
  LINE2="${LINE2}  ${D}|${N}  ${Y}${BRANCH}${N}"
fi
if [ "$LINES_ADD" -gt 0 ] || [ "$LINES_DEL" -gt 0 ]; then
  LINE2="${LINE2}  ${D}|${N}  ${G}+${LINES_ADD}${N}${D}/${N}${R}-${LINES_DEL}${N}"
fi
if [ -n "$AGENT" ]; then
  LINE2="${LINE2}  ${D}|${N}  ${C}agent:${AGENT}${N}"
fi
if [ -n "$WORKTREE" ]; then
  LINE2="${LINE2}  ${D}|${N}  wt:${WORKTREE}(${WT_BRANCH})"
fi

echo -e "$LINE1"
echo -e "$LINE2"
