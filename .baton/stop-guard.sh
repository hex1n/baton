#!/bin/sh
# stop-guard.sh — Advisory: remind about incomplete tasks when stopping
# Version: 2.0
#
# Hook: Stop
# Always exit 0 — never block the stop action
#
# Checks: only during implement phase (plan + GO marker + unchecked TODOs)
# Plan file override: BATON_PLAN=custom-plan.md (default: plan.md)

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON stop-guard: unexpected error, skipping reminder" >&2; exit 0' HUP INT TERM

PLAN_NAME="${BATON_PLAN:-plan.md}"
# SYNCED: find_plan — same algorithm in write-lock.sh, phase-guide.sh, bash-guard.sh
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done

# Only check during implement phase (plan exists + GO marker)
[ -z "$PLAN" ] && exit 0
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0

# Count unchecked TODO items
TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
DONE=$(grep -c '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0
REMAINING=$((TOTAL - DONE))

if [ "$REMAINING" -gt 0 ]; then
    echo "" >&2
    echo "📋 Implementation in progress: $DONE/$TOTAL items done, $REMAINING remaining." >&2
    echo "   Next session can resume from the $PLAN_NAME checklist." >&2
    echo "   💡 Review changes before closing: git diff --stat" >&2
    echo "   💡 Consider appending '## Lessons Learned' to $PLAN_NAME before stopping." >&2
fi

exit 0
