#!/bin/sh
# post-write-tracker.sh — Advisory: warn when modified files aren't in the plan
# Version: 1.0
#
# Hook: PostToolUse (Edit|Write|MultiEdit|CreateFile)
# Always exit 0 — PostToolUse cannot block, this is advisory only
#
# Checks if the modified file appears in plan.md's ## Todo section.
# If not, outputs a warning to stderr.

# --- Fail-open on unexpected errors ---
trap 'exit 0' HUP INT TERM

[ "${BATON_BYPASS:-}" = "1" ] && exit 0

# --- Read stdin JSON ---
STDIN=""
if [ ! -t 0 ]; then
    STDIN="$(cat 2>/dev/null || true)"
fi

# --- Resolve target path ---
TARGET="${BATON_TARGET:-}"
if [ -z "$TARGET" ] && [ -n "$STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
        TARGET="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // empty')"
    else
        TARGET="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)
        }' | head -1)"
    fi
fi

[ -z "$TARGET" ] && exit 0

# Markdown files are always allowed, no need to track
case "$TARGET" in
    *.md|*.MD|*.markdown|*.mdx) exit 0 ;;
esac

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

# --- Check if file is mentioned in plan ---
BASENAME="$(basename "$TARGET")"
if ! grep -q "$BASENAME" "$PLAN" 2>/dev/null; then
    echo "⚠️ Modified $BASENAME — not mentioned in $PLAN_NAME." >&2
    echo "   If this is necessary, update the plan before continuing." >&2
fi

exit 0
