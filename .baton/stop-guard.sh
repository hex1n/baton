#!/bin/sh
# stop-guard.sh — Advisory: remind about incomplete tasks when stopping
# Version: 3.0
#
# Hook: Stop
# Always exit 0 — never block the stop action
#
# Checks: implement phase (plan + GO marker + unchecked TODOs)
#         archival phase (plan + GO marker + all TODOs done)
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

# Count TODO items
TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
DONE=$(grep -c '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0
REMAINING=$((TOTAL - DONE))

if [ "$TOTAL" -gt 0 ] && [ "$REMAINING" -eq 0 ]; then
    # All done — archival reminder
    echo "" >&2
    echo "✅ All todo items complete." >&2
    echo "📋 Consider archiving: mkdir -p plans && mv $PLAN_NAME plans/\${PLAN_NAME%.md}-\$(date +%Y-%m-%d)-topic.md" >&2
    echo "💡 The Annotation Log records design decision rationale — valuable long-term reference." >&2
elif [ "$REMAINING" -gt 0 ]; then
    # In progress — progress reminder
    echo "" >&2
    echo "📋 Implementation in progress: $DONE/$TOTAL items done, $REMAINING remaining." >&2
    echo "   Next session can resume from the $PLAN_NAME checklist." >&2
    echo "   💡 Consider appending '## Lessons Learned' to $PLAN_NAME before stopping." >&2
fi

exit 0