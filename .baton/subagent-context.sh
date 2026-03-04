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

# --- Find plan file ---
# SYNCED: plan-name-resolution — same in all baton scripts
if [ -n "$BATON_PLAN" ]; then
    PLAN_NAME="$BATON_PLAN"
else
    _candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
    PLAN_NAME="${_candidate:-plan.md}"
fi
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done

[ -z "$PLAN" ] && exit 0
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0

# --- Output plan context ---
TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
DONE=$(grep -ci '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0

echo "📋 Baton plan context ($DONE/$TOTAL items done):" >&2
# Output todo items (up to 20 lines to avoid flooding)
grep '^\- \[' "$PLAN" 2>/dev/null | head -20 >&2

exit 0
