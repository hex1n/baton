#!/usr/bin/env bash
# dispatch-cursor.sh — Cursor adapter for dispatch.sh
# Translates dispatch.sh exit codes to Cursor's JSON response protocol.
# Cursor expects: {"decision":"allow"} or {"decision":"block","reason":"..."}
set -eu

_dir="$(cd "$(dirname "$0")" && pwd)"
_hooks_dir="$_dir/../../hooks"

# Cursor uses camelCase event names — map to dispatch.sh PascalCase
_event="$1"
case "$_event" in
    sessionStart)     _event="SessionStart" ;;
    preToolUse)       _event="PreToolUse" ;;
    postToolUse)      _event="PostToolUse" ;;
    subagentStart)    _event="SubagentStart" ;;
    preCompact)       _event="PreCompact" ;;
    stop)             _event="Stop" ;;
    taskCompleted)    _event="TaskCompleted" ;;
    postToolUseFailure) _event="PostToolUseFailure" ;;
esac

_out=""
_rc=0
_out="$(bash "$_hooks_dir/dispatch.sh" "$_event" 2>&1)" || _rc=$?

if [ "$_rc" -eq 2 ]; then
    # Escape output for JSON
    _reason="$(printf '%s' "$_out" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')"
    printf '{"decision":"block","reason":"%s"}\n' "$_reason"
else
    printf '{"decision":"allow"}\n'
fi
