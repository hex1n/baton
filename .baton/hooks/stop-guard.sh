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

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan

# Only check during implement phase (plan exists + GO marker)
[ -z "$PLAN" ] && exit 0
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0

# Count TODO items
TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
DONE=$(grep -ci '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0
REMAINING=$((TOTAL - DONE))

if [ "$TOTAL" -gt 0 ] && [ "$REMAINING" -eq 0 ]; then
    # All done — retrospective + archival reminder
    echo "" >&2
    echo "✅ All todo items complete." >&2
    echo "📋 Before archiving, append ## Retrospective to $PLAN_NAME: what did the plan get wrong?" >&2
    echo "   Then: mkdir -p plans && mv $PLAN_NAME plans/\${PLAN_NAME%.md}-\$(date +%Y-%m-%d)-topic.md" >&2
    echo "💡 The Annotation Log records design decision rationale — valuable long-term reference." >&2
elif [ "$REMAINING" -gt 0 ]; then
    # In progress — progress reminder
    echo "" >&2
    echo "📋 Implementation in progress: $DONE/$TOTAL items done, $REMAINING remaining." >&2
    echo "   Next session can resume from the $PLAN_NAME checklist." >&2
    echo "   💡 Consider appending '## Lessons Learned' to $PLAN_NAME before stopping." >&2
fi

exit 0