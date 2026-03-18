#!/usr/bin/env bash
# pre-compact.sh — Preserve key context before context compression
# Version: 1.1
#
# Hook: PreCompact
# Always exit 0 — PreCompact cannot block
#
# Outputs plan progress summary and recent Annotation Log entries to stderr,
# ensuring critical context survives context window compression.

# --- Fail-open on unexpected errors ---
trap 'exit 0' HUP INT TERM

[ "${BATON_BYPASS:-}" = "1" ] && exit 0

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan

[ -z "$PLAN" ] && exit 0

# --- Output progress summary ---
echo "📋 Baton context snapshot (pre-compression):" >&2

if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    parser_todo_range
    parser_todo_counts
    if [ "${TODO_START:-0}" -eq 0 ] 2>/dev/null; then
        echo "   Phase: AWAITING_TODO" >&2
    elif [ "$TODO_TOTAL" -gt 0 ] && [ "$TODO_REMAINING" -eq 0 ]; then
        echo "   Phase: FINISH ($TODO_DONE/$TODO_TOTAL items done)" >&2
    else
        echo "   Phase: IMPLEMENT ($TODO_DONE/$TODO_TOTAL items done)" >&2
        # Show remaining items
        parser_todo_remaining_items "$PLAN" | head -5 >&2
    fi
else
    echo "   Phase: PLAN/ANNOTATION (awaiting BATON:GO)" >&2
fi

# --- Output last Annotation Log round (if exists) ---
if grep -q '## Annotation Log' "$PLAN" 2>/dev/null; then
    echo "   Recent decisions from Annotation Log available in $PLAN_NAME." >&2
fi

exit 0
