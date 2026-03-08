#!/bin/sh
# completion-check.sh — Block task completion until retrospective is written
# Version: 1.0
#
# Hook: TaskCompleted
# Exit 0 = allow completion
# Exit 2 = block completion (with message)
#
# When all todo items are done but no ## Retrospective exists,
# blocks completion and reminds to write retrospective.

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

# --- Check if all todos are done ---
TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
DONE=$(grep -ci '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0

# Only enforce retrospective when all items are complete
[ "$TOTAL" -eq 0 ] && exit 0
[ "$TOTAL" -ne "$DONE" ] && exit 0

# --- Check for retrospective ---
if ! grep -qi '^## Retrospective' "$PLAN" 2>/dev/null; then
    echo "📋 All todo items complete, but no ## Retrospective found in $PLAN_NAME." >&2
    echo "   Before completing, append ## Retrospective:" >&2
    echo "   · What did the plan get wrong?" >&2
    echo "   · What surprised you during implementation?" >&2
    echo "   · What would you research differently next time?" >&2
    exit 2
fi

exit 0
