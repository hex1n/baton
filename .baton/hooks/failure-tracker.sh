#!/usr/bin/env bash
# failure-tracker.sh — Session-total PostToolUseFailure counter with threshold alerts
# Version: 1.0
#
# Hook: PostToolUseFailure (matcher: "")
# Advisory only — always exit 0
#
# Counts cumulative tool failures per session. Alerts at threshold =3 and =5 only.
# Does not attempt root-cause analysis — provides "failures accumulating" signal.

# --- Read stdin JSON (supports dispatch mode and direct invocation) ---
if [ -n "${BATON_STDIN+x}" ]; then
    STDIN="$BATON_STDIN"
else
    STDIN=""
    [ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"
fi

# --- Extract session identifier ---
# Try session_id from JSON first, fall back to PPID
SESSION_ID=""
TOOL_NAME=""
if [ -n "$STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
        SESSION_ID="$(printf '%s' "$STDIN" | jq -r '.session_id // .sessionId // empty' 2>/dev/null)"
        TOOL_NAME="$(printf '%s' "$STDIN" | jq -r '.tool_name // .toolName // empty' 2>/dev/null)"
    else
        SESSION_ID="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="session_id" || $i=="sessionId") { print $(i+2); exit }
        }')"
        TOOL_NAME="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="tool_name" || $i=="toolName") { print $(i+2); exit }
        }')"
    fi
fi

# Fallback: use PPID as session proxy (stable within a Claude Code session)
if [ -z "$SESSION_ID" ]; then
    SESSION_ID="${PPID:-unknown}"
fi

# Session ids may contain separators or whitespace; sanitize before using them
# as part of a temp-file path.
SESSION_ID="$(printf '%s' "$SESSION_ID" | tr -c 'A-Za-z0-9._-' '_')"

# --- Count file ---
COUNT_FILE="/tmp/baton-failures-${SESSION_ID}"

# Append failure record
echo "${TOOL_NAME:-unknown} $(date +%s)" >> "$COUNT_FILE"

# --- Count and threshold check ---
COUNT=$(wc -l < "$COUNT_FILE" 2>/dev/null | tr -d ' ')

if [ "$COUNT" -eq 3 ] 2>/dev/null; then
    echo "⚠️ 3 tool failures this session — consider whether recent failures share a root cause (constitution.md Failure boundary). If yes, invoke /baton-debug." >&2
elif [ "$COUNT" -eq 5 ] 2>/dev/null; then
    echo "⚠️ 5 tool failures this session — 3-failure rule likely applies." >&2
fi

exit 0
