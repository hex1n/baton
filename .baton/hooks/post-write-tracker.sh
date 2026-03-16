#!/usr/bin/env bash
# post-write-tracker.sh — Advisory: warn when modified files aren't in the plan
# Version: 1.0
#
# Hook: PostToolUse (Edit|Write|MultiEdit|CreateFile)
# Always exit 0 — PostToolUse cannot block, this is advisory only
#
# Checks if the modified file appears in plan.md's ## Todo section write set.
# If not, outputs a warning to stderr.

# --- Fail-open on unexpected errors ---
trap 'exit 0' HUP INT TERM

[ "${BATON_BYPASS:-}" = "1" ] && exit 0

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

# Resolve relative target paths against JSON_CWD
if [ -n "$JSON_CWD" ] && [ -n "$TARGET" ]; then
    case "$TARGET" in
        /*) ;; # absolute, keep as-is
        *)
            TARGET="${JSON_CWD}/${TARGET}"
            # Canonicalize to resolve ../ (portable: cd to parent + pwd)
            _parent="$(dirname "$TARGET")"
            if [ -d "$_parent" ]; then
                TARGET="$(cd "$_parent" 2>/dev/null && pwd)/$(basename "$TARGET")"
            else
                TARGET="$(realpath -m "$TARGET" 2>/dev/null || readlink -f "$TARGET" 2>/dev/null || echo "$TARGET")"
            fi
            ;;
    esac
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
parser_has_go || exit 0

# --- Check if file is in the plan's write set ---
_writeset="$(parser_writeset_extract)"
if [ -n "$_writeset" ]; then
    # Exact path matching against Files: fields in ## Todo section
    _normalized="$(parser_writeset_normalize "$TARGET")"
    if ! printf '%s\n' "$_writeset" | grep -qxF "$_normalized"; then
        echo "⚠️ Modified $_normalized — not in $PLAN_NAME write set." >&2
        echo "   Expected files:" >&2
        printf '%s\n' "$_writeset" | sed 's/^/   · /' >&2
        echo "   If this is necessary, update the plan before continuing." >&2
    fi
else
    # Fallback: no Files: fields, check basename against plan text
    _basename="$(basename "$TARGET")"
    if ! grep -q "$_basename" "$PLAN" 2>/dev/null; then
        echo "⚠️ Modified $_basename — not mentioned in $PLAN_NAME." >&2
        echo "   If this is necessary, update the plan before continuing." >&2
    fi
fi

exit 0
