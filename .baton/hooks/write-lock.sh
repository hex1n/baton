#!/bin/sh
# write-lock.sh — Block source code writes until plan file contains <!-- BATON:GO -->
# Version: 3.0
#
# Hook: PreToolUse (Edit|Write|MultiEdit|CreateFile)
# Unlock: Add <!-- BATON:GO --> anywhere in plan file
# Re-lock: Remove <!-- BATON:GO -->
# Always allowed: *.md, *.mdx files
#
# Target: $BATON_TARGET env > stdin JSON .tool_input.file_path
# Plan file override: BATON_PLAN=custom-plan.md (default: plan.md)

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON write-lock: unexpected error, allowing operation (fail-open)" >&2; exit 0' HUP INT TERM

# --- Emergency bypass ---
if [ "${BATON_BYPASS:-}" = "1" ]; then
    echo "⚠️ Write lock bypassed (BATON_BYPASS=1)" >&2
    exit 0
fi

# --- Read stdin JSON ---
STDIN=""
if [ ! -t 0 ]; then
    STDIN="$(cat 2>/dev/null || true)"
fi

# --- Resolve target path + cwd from JSON ---
TARGET="${BATON_TARGET:-}"
JSON_CWD=""

if [ -z "$TARGET" ] && [ -n "$STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
        TARGET="$(printf '%s' "$STDIN" | jq -r '.tool_input.file_path // empty')"
        JSON_CWD="$(printf '%s' "$STDIN" | jq -r '.cwd // empty')"
    else
        TARGET="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="file_path") print $(i+2)
        }' | head -1)"
        JSON_CWD="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="cwd") print $(i+2)
        }' | head -1)"
    fi
fi

# Can't determine target → fail-open (but visible)
if [ -z "$TARGET" ]; then
    echo "⚠️ Write lock: could not determine target path; allowing (fail-open)" >&2
    if ! command -v jq >/dev/null 2>&1; then
        echo "⚠️ Install jq for reliable path parsing (currently using awk fallback)" >&2
    fi
    exit 0
fi

# --- Markdown always allowed ---
case "$TARGET" in
    *.md|*.MD|*.markdown|*.mdx) exit 0 ;;
esac

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    echo "⚠️ BATON write-lock: _common.sh not found, allowing operation (fail-open)" >&2
    exit 0
fi

# --- Find plan file (from JSON cwd, then shell cwd) ---
resolve_plan_name
find_plan

# --- No plan → block + research phase guidance ---
if [ -z "$PLAN" ]; then
    echo "🔒 Blocked: no $PLAN_NAME found." >&2
    echo "📍 Complete research (research.md) first, then write plan (plan.md). Simple changes may skip straight to plan.md." >&2
    exit 1
fi

# --- Check GO marker ---
if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    exit 0
fi

# --- Plan exists, no GO → block + plan phase guidance ---
echo "🔒 Blocked: $PLAN_NAME not approved." >&2
echo "📍 Annotation cycle in progress. Add <!-- BATON:GO --> after approval to unlock." >&2
exit 1
