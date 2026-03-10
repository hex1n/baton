#!/usr/bin/env bash
# pre-compact.sh — Preserve key context before context compression
# Version: 1.0
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
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan

[ -z "$PLAN" ] && exit 0

# --- Output progress summary ---
echo "📋 Baton context snapshot (pre-compression):" >&2

if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
    DONE=$(grep -ci '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0
    echo "   Phase: IMPLEMENT ($DONE/$TOTAL items done)" >&2
    # Show remaining items
    grep '^\- \[ \]' "$PLAN" 2>/dev/null | head -5 >&2
else
    echo "   Phase: PLAN/ANNOTATION (awaiting BATON:GO)" >&2
fi

# --- Output last Annotation Log round (if exists) ---
if grep -q '## Annotation Log' "$PLAN" 2>/dev/null; then
    echo "   Recent decisions from Annotation Log available in $PLAN_NAME." >&2
fi

exit 0
