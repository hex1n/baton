#!/usr/bin/env bash
# write-lock.sh — Block source code writes until plan file contains <!-- BATON:GO -->
# Version: 3.1
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

# --- Read stdin JSON (supports dispatch mode and direct invocation) ---
if [ -n "${BATON_STDIN+x}" ]; then
    STDIN="$BATON_STDIN"
else
    STDIN=""
    [ ! -t 0 ] && STDIN="$(cat 2>/dev/null || true)"
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

_canonicalize_path() {
    local _base="$1"
    local _path="$2"
    local _candidate
    case "$_path" in
        /*) _candidate="$_path" ;;
        *) _candidate="$_base/$_path" ;;
    esac
    _candidate="$(realpath -m "$_candidate" 2>/dev/null || readlink -f "$_candidate" 2>/dev/null)" || true
    if [ -n "$_candidate" ]; then
        printf '%s\n' "$_candidate"
        return
    fi

    local _parent _name
    _name="$(basename "$_path")"
    case "$_path" in
        /*) _parent="$(dirname "$_path")" ;;
        *) _parent="$_base/$(dirname "$_path")" ;;
    esac
    if [ -d "$_parent" ]; then
        printf '%s/%s\n' "$(cd "$_parent" 2>/dev/null && pwd)" "$_name"
    else
        case "$_path" in
            /*) printf '%s\n' "$_path" ;;
            *) printf '%s/%s\n' "$_base" "$_path" ;;
        esac
    fi
}

# --- Files outside Baton project root always allowed ---
SESSION_DIR="${JSON_CWD:-$(pwd)}"
PROJECT_DIR="$(parser_project_root "$SESSION_DIR")"
PROJECT_DIR="$(cd "$PROJECT_DIR" 2>/dev/null && pwd || printf '%s' "$PROJECT_DIR")"
TARGET_REAL="$(_canonicalize_path "$SESSION_DIR" "$TARGET")"
case "$TARGET_REAL" in
    "$PROJECT_DIR"|"$PROJECT_DIR"/*) ;;  # inside project, continue checks
    *) exit 0 ;;                          # outside project, allow
esac

# --- No plan → block + research phase guidance ---
if [ -z "$PLAN" ]; then
    echo "🔒 Blocked: no $PLAN_NAME found." >&2
    echo "📍 Complete research first, then write a plan. Simple changes may skip straight to planning." >&2
    exit 2
fi

# --- Multi-plan ambiguity → fail-closed ---
if [ "${MULTI_PLAN_COUNT:-0}" -gt 1 ] 2>/dev/null && [ -z "${BATON_PLAN:-}" ]; then
    echo "🔒 Blocked: $MULTI_PLAN_COUNT plan files found — ambiguous." >&2
    echo "📍 Set BATON_PLAN=<filename> to select one, or remove unused plans." >&2
    exit 2
fi

# --- Check GO marker ---
if parser_has_go; then
    # Plan-approved write — inject self-check reminder via additionalContext
    cat <<'HOOKJSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"Baton: verify this file is in the approved write set. Self-check after writing."}}
HOOKJSON
    exit 0
fi

# --- Plan exists, no GO → block + plan phase guidance ---
echo "🔒 Blocked: $PLAN_NAME not approved." >&2
echo "📍 Annotation cycle in progress. Add <!-- BATON:GO --> after approval to unlock." >&2
exit 2
