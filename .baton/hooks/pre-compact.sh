#!/usr/bin/env bash
# pre-compact.sh — Preserve key context before context compression
# Version: 1.2
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

# --- Output authorized write set ---
_writeset="$(parser_writeset_extract 2>/dev/null)"
if [ -n "$_writeset" ]; then
    echo "   Authorized write set:" >&2
    printf '%s\n' "$_writeset" | head -10 | while IFS= read -r _f; do
        echo "     $_f" >&2
    done
fi

# --- Output last Annotation Log content (if exists) ---
if grep -q '## Annotation Log' "$PLAN" 2>/dev/null; then
    _anno_content="$(awk '/^## Annotation Log/{f=1; next} /^## [^#]/{if(f) exit} f{print}' "$PLAN" 2>/dev/null | tail -10)"
    if [ -n "$_anno_content" ]; then
        echo "   Recent Annotation Log:" >&2
        printf '%s\n' "$_anno_content" | while IFS= read -r _line; do
            echo "     $_line" >&2
        done
    else
        echo "   Annotation Log: present but no recent content." >&2
    fi
fi

exit 0
