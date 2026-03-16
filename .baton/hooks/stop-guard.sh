#!/usr/bin/env bash
# stop-guard.sh — Advisory: remind about incomplete tasks when stopping
# Version: 3.0
#
# Hook: Stop
# Always exit 0 — never block the stop action
#
# Checks: implement phase (plan + GO marker + unchecked Todo items)
#         finish phase (plan + GO marker + all Todo items done)
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

# Count Todo items
parser_todo_counts

if [ "$TODO_TOTAL" -gt 0 ] && [ "$TODO_REMAINING" -eq 0 ]; then
    # All done — finish workflow reminder
    echo "" >&2
    echo "✅ All Todo items complete — FINISH phase." >&2
    echo "📍 Complete the finish workflow before stopping:" >&2
    echo "   1. Append ## Retrospective to $PLAN_NAME (≥3 lines, answer all three):" >&2
    echo "      · What did the plan get wrong?" >&2
    echo "      · What surprised you during implementation?" >&2
    echo "      · What would you research differently next time?" >&2
    echo "   2. Run the full test suite to verify nothing is broken" >&2
    echo "   3. Mark complete: add <!-- BATON:COMPLETE --> on its own line in $PLAN_NAME" >&2
    echo "   4. Decide branch disposition (merge, keep, or discard)" >&2
    echo "💡 The Annotation Log records design decision rationale — valuable long-term reference." >&2
elif [ "$TODO_REMAINING" -gt 0 ]; then
    # In progress — progress reminder
    echo "" >&2
    echo "📋 Implementation in progress: $TODO_DONE/$TODO_TOTAL Todo items done, $TODO_REMAINING remaining." >&2
    echo "   Next session can resume from the $PLAN_NAME checklist." >&2
    echo "   💡 Consider appending '## Lessons Learned' to $PLAN_NAME before stopping." >&2
fi

exit 0