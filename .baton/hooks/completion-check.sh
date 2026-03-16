#!/usr/bin/env bash
# completion-check.sh — Block task completion until retrospective is written
# Version: 1.1
#
# Hook: TaskCompleted
# Exit 0 = allow completion
# Exit 2 = block completion (with message)
#
# When all Todo items are done but no ## Retrospective exists,
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

# --- Multi-plan ambiguity → fail-closed ---
if [ "${MULTI_PLAN_COUNT:-0}" -gt 1 ] 2>/dev/null && [ -z "${BATON_PLAN:-}" ]; then
    echo "🔒 Blocked: $MULTI_PLAN_COUNT plan files found — ambiguous." >&2
    echo "📍 Set BATON_PLAN=<filename> to select one, or remove unused plans." >&2
    exit 2
fi

[ -z "$PLAN" ] && exit 0
grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null || exit 0

# --- Check if all todos are done ---
parser_todo_counts

# Only enforce retrospective when all items are complete
[ "$TODO_TOTAL" -eq 0 ] && exit 0
[ "$TODO_TOTAL" -ne "$TODO_DONE" ] && exit 0

# --- Check for retrospective (exact header + ≥3 non-empty content lines) ---
parser_retro_range
if [ "${RETRO_START:-0}" -eq 0 ] 2>/dev/null; then
    echo "📋 FINISH phase: all Todo items complete, but no ## Retrospective found in $PLAN_NAME." >&2
    echo "   Complete the finish workflow — append ## Retrospective:" >&2
    echo "   · What did the plan get wrong?" >&2
    echo "   · What surprised you during implementation?" >&2
    echo "   · What would you research differently next time?" >&2
    exit 2
fi

if ! parser_retro_valid; then
    echo "📋 FINISH phase: ## Retrospective exists but has only ${RETRO_LINE_COUNT:-0} content line(s) — need ≥3." >&2
    echo "   Complete the finish workflow — answer all three questions:" >&2
    echo "   · What did the plan get wrong?" >&2
    echo "   · What surprised you during implementation?" >&2
    echo "   · What would you research differently next time?" >&2
    exit 2
fi

exit 0
