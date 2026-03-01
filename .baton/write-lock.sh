#!/bin/sh
# write-lock.sh — Block source code writes until plan file contains <!-- BATON:GO -->
# Version: 2.0
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

# --- Find plan file (from JSON cwd, then shell cwd) ---
PLAN_NAME="${BATON_PLAN:-plan.md}"

# SYNCED: find_plan — same algorithm in phase-guide.sh, stop-guard.sh, bash-guard.sh
# Changes here must be mirrored. Validated by test-workflow-consistency.sh
find_plan() {
    d="${JSON_CWD:-$(pwd)}"
    while true; do
        [ -f "$d/$PLAN_NAME" ] && { echo "$d/$PLAN_NAME"; return; }
        p="$(dirname "$d")"
        [ "$p" = "$d" ] && return
        d="$p"
    done
}

PLAN="$(find_plan)"

# --- No plan → block + research phase guidance ---
if [ -z "$PLAN" ]; then
    echo "🔒 Blocked: no $PLAN_NAME found." >&2
    echo "📍 Write research.md first (Scope | Architecture | Constraints | Patterns | Risks | Key files | Coverage)" >&2
    exit 1
fi

# --- Check GO marker ---
if grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    exit 0
fi

# --- Plan exists, no GO → block + plan phase guidance ---
echo "🔒 Blocked: $PLAN_NAME not unlocked." >&2
echo "📍 Refine plan: declare scope, concrete verification, self-review risks, wait for <!-- BATON:GO -->" >&2
exit 1
