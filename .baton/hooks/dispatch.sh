#!/usr/bin/env bash
# dispatch.sh — event-based hook dispatcher
# Runs each hook in a subshell to isolate exit codes and variable state.
# Buffers stdin so multiple hooks can access the input payload.
set -eu

_event="$1"; shift
_dir="$(cd "$(dirname "$0")" && pwd)"
_manifest="$_dir/manifest.conf"

[ ! -f "$_manifest" ] && exit 0

# Export project dir before junction resolution changes pwd context
export BATON_PROJECT_DIR
BATON_PROJECT_DIR="$(pwd)"

# Buffer stdin once — hook scripts read from BATON_STDIN instead of stdin.
# Claude Code passes tool name and input as JSON on stdin to hooks.
export BATON_STDIN
BATON_STDIN="$(cat 2>/dev/null || true)"

# Extract tool name from stdin JSON for matcher filtering.
# PreToolUse/PostToolUse stdin has "tool_name" field.
_tool=""
if [ -n "$BATON_STDIN" ]; then
    _tool="$(printf '%s' "$BATON_STDIN" | jq -r '.tool_name // empty' 2>/dev/null)" || true
    # sed fallback if jq unavailable
    if [ -z "$_tool" ]; then
        _tool="$(printf '%s' "$BATON_STDIN" | sed -n 's/.*"tool_name" *: *"\([^"]*\)".*/\1/p' | head -1)" || true
    fi
fi

_exit_code=0

while IFS=: read -r _evt _matcher _script || [ -n "$_evt" ]; do
    # Strip CR for Windows CRLF compatibility (core.autocrlf=true)
    _evt="${_evt%$'\r'}"; _matcher="${_matcher%$'\r'}"; _script="${_script%$'\r'}"
    case "$_evt" in ''|\#*) continue ;; esac
    [ "$_evt" != "$_event" ] && continue

    if [ -n "$_matcher" ]; then
        # Matcher specified but no tool name available = skip
        [ -z "$_tool" ] && continue
        case ",$_matcher," in
            *",$_tool,"*) ;;
            *) continue ;;
        esac
    fi

    # Run in subshell: isolates exit codes and variable state
    _rc=0
    ( . "$_dir/$_script.sh" ) || _rc=$?

    # For PreToolUse: first blocking exit (exit 2) wins
    if [ "$_rc" -eq 2 ] && [ "$_exit_code" -ne 2 ]; then
        _exit_code=2
    fi
    # Surface unexpected exit codes (not 0=ok, not 2=block) so hook crashes aren't silent
    if [ "$_rc" -ne 0 ] && [ "$_rc" -ne 2 ]; then
        echo "⚠️ BATON dispatch: $_script.sh exited with unexpected code $_rc (expected 0 or 2)" >&2
    fi
done < "$_manifest"

exit "$_exit_code"
