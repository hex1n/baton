#!/usr/bin/env bash
# bash-guard.sh — Block explicit shell writes when plan gate is closed
# Version: 3.3
# Hook: PreToolUse (Bash)
# Exit 0 = allow, Exit 2 = block
#
# When gate is open (BATON:GO present): always allows.
# When gate is closed: blocks explicit file-write patterns, warns on ambiguous ones.

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON bash-guard: unexpected error, allowing (fail-open)" >&2; exit 0' HUP INT TERM

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/lib/common.sh" ]; then
    . "$SCRIPT_DIR/lib/common.sh"
else
    exit 0
fi
resolve_plan_name
find_plan

# --- Gate open → allow everything ---
if [ -n "$PLAN" ]; then
    # Multi-plan ambiguity without BATON_PLAN → treat as gate-closed
    if [ "${MULTI_PLAN_COUNT:-0}" -gt 1 ] 2>/dev/null && [ -z "${BATON_PLAN:-}" ]; then
        : # fall through to command check
    elif parser_has_go; then
        exit 0
    fi
fi

# --- Read command from stdin JSON (supports dispatch mode and direct invocation) ---
if [ -n "${BATON_STDIN+x}" ]; then
    STDIN="$BATON_STDIN"
elif [ ! -t 0 ]; then
    STDIN="$(cat 2>/dev/null || true)"
else
    STDIN=""
fi
if [ -n "$STDIN" ]; then
    if command -v jq >/dev/null 2>&1; then
        CMD="$(printf '%s' "$STDIN" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    else
        CMD="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="command") { print $(i+2); exit }
        }')"
    fi
fi

[ -z "${CMD:-}" ] && exit 0

# --- Quote stripping: remove content inside single/double quotes ---
strip_quoted_segments() {
    local _input="$1"
    local _out=""
    local _state="plain"
    local _escaped=0
    local _i _ch
    for ((_i = 0; _i < ${#_input}; _i++)); do
        _ch="${_input:_i:1}"
        case "$_state" in
            single)
                [ "$_ch" = "'" ] && _state="plain"
                continue
                ;;
            double)
                if [ "$_escaped" = "1" ]; then
                    _escaped=0
                    continue
                fi
                case "$_ch" in
                    "\\") _escaped=1 ;;
                    '"') _state="plain" ;;
                esac
                continue
                ;;
        esac
        case "$_ch" in
            "'") _state="single" ;;
            '"') _state="double" ;;
            *) _out="${_out}${_ch}" ;;
        esac
    done
    printf '%s\n' "$_out"
}

has_output_redirection() {
    printf '%s\n' "$1" | grep -Eq '(^|[^<])([012]?>>?|>>?)[[:space:]]*[^&[:space:]]'
}

_SCAN_CMD="$(strip_quoted_segments "$CMD")"

# Helper: check if a token appears as a command (after ;|&( or at start)
# Also matches path-qualified variants: /bin/cp, /usr/bin/tee, etc.
_is_cmd_token() {
    printf '%s\n' "$_SCAN_CMD" | grep -qE "(^|[;&|(]\s*)(/[^ ]*/)?$1(\s|$)"
}

# --- Phase-1 block list: explicit shell write patterns ---
_blocked=""
if printf '%s\n' "$_SCAN_CMD" | grep -Eq '<<[-]?[[:space:]]*[^>]*>[[:space:]]*[^&[:space:]]'; then
    _blocked="heredoc with redirect"
elif has_output_redirection "$_SCAN_CMD"; then
    _blocked="output redirection"
fi

# tee — standalone or piped (word-boundary aware)
if [ -z "$_blocked" ] && _is_cmd_token 'tee'; then
    _blocked="tee (write sink)"
fi

# In-place editors (checked on quote-stripped command)
if [ -z "$_blocked" ]; then
    case "$_SCAN_CMD" in
        *"sed -i"*)
            _blocked="sed -i (in-place edit)" ;;
        *"perl -pi"*)
            _blocked="perl -pi (in-place edit)" ;;
    esac
fi

# python -c with file write patterns (check raw $CMD — write pattern is inside quotes)
if [ -z "$_blocked" ]; then
    case "$_SCAN_CMD" in
        *"python -c"*|*"python3 -c"*)
            case "$CMD" in
                *"open("*"'w'"*|*"open("*"'a'"*|*'open('*'"w"'*|*'open('*'"a"'*)
                    _blocked="python -c with file write" ;;
            esac
            ;;
    esac
fi

# File mutation commands (word-boundary aware, on quote-stripped command)
if [ -z "$_blocked" ] && _is_cmd_token 'cp'; then
    _blocked="cp (file copy)"
elif [ -z "$_blocked" ] && _is_cmd_token 'mv'; then
    _blocked="mv (file move)"
elif [ -z "$_blocked" ] && _is_cmd_token 'install'; then
    _blocked="install (file install)"
elif [ -z "$_blocked" ] && _is_cmd_token 'truncate'; then
    _blocked="truncate"
elif [ -z "$_blocked" ] && _is_cmd_token 'patch'; then
    _blocked="patch (in-place diff application)"
fi

if [ -n "$_blocked" ]; then
    echo "🔒 Blocked: shell write detected ($_blocked) while plan gate is closed." >&2
    echo "📍 Add <!-- BATON:GO --> to your plan to unlock writes." >&2
    exit 2
fi

# --- Phase-1 warn-only: ambiguous patterns ---
if _is_cmd_token 'rm'; then
    echo "⚠️ Bash guard: 'rm' detected while plan gate is closed (destructive — verify intent)." >&2
fi
case "$_SCAN_CMD" in
    *"touch "*)
        echo "⚠️ Bash guard: 'touch' detected while plan gate is closed (allowed, but verify intent)." >&2
        ;;
esac

exit 0
