#!/bin/sh
# subagent-context.sh — Inject plan context when a subagent starts
# Version: 1.0
#
# Hook: SubagentStart
# Always exit 0 — SubagentStart cannot block
#
# Outputs the current plan's ## Todo section and progress to stderr,
# so subagents have awareness of the overall plan.

# --- Fail-open on unexpected errors ---
trap 'exit 0' HUP INT TERM

[ "${BATON_BYPASS:-}" = "1" ] && exit 0

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan

[ -z "$PLAN" ] && exit 0
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0

# --- Output plan context ---
TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
DONE=$(grep -ci '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0

echo "📋 Baton plan context ($DONE/$TOTAL items done):" >&2
# Output todo items (up to 20 lines to avoid flooding)
grep '^\- \[' "$PLAN" 2>/dev/null | head -20 >&2

exit 0
