#!/bin/sh
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

# --- Find plan file ---
# SYNCED: plan-name-resolution — same in all baton scripts
if [ -n "$BATON_PLAN" ]; then
    PLAN_NAME="$BATON_PLAN"
else
    _candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
    PLAN_NAME="${_candidate:-plan.md}"
fi
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done

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
