#!/usr/bin/env bash
# subagent-context.sh — Inject plan context when a subagent starts
# Version: 1.2
#
# Hook: SubagentStart
# Always exit 0 — SubagentStart cannot block
#
# Outputs the current plan's ## Todo section and Todo progress to stderr,
# so subagents have awareness of the overall plan.

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

# --- Without BATON:GO: surface phase context only ---
if ! grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    echo "📋 Baton: $PLAN_NAME exists — ANNOTATION phase (awaiting BATON:GO)." >&2
    exit 0
fi

# --- Output plan context ---
parser_todo_counts

echo "📋 Baton plan context ($TODO_DONE/$TODO_TOTAL items done):" >&2
# Output Todo items (up to 20 lines to avoid flooding)
parser_todo_items "$PLAN" | head -20 >&2

# --- Inject authorized write set so subagent knows scope boundary ---
_writeset="$(parser_writeset_extract 2>/dev/null)"
if [ -n "$_writeset" ]; then
    echo "🔒 Authorized write set:" >&2
    printf '%s\n' "$_writeset" | head -20 | while IFS= read -r _f; do
        echo "   $_f" >&2
    done
fi

exit 0
