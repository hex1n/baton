#!/usr/bin/env bash
# dispatch-codex.sh — Codex adapter for dispatch.sh
# SessionStart expects hook JSON on stdout.
# Stop expects valid Stop-hook JSON on stdout, so human-readable reminder text
# must stay off the protocol channel.
set -eu

_event="${1:-}"
_dir="$(cd "$(dirname "$0")" && pwd)"
_dispatch="$_dir/../../hooks/dispatch.sh"

case "$_event" in
    SessionStart)
        bash "$_dispatch" "$@" || true
        ;;
    Stop)
        _stop_msg="$(bash "$_dispatch" "$@" 2>&1 1>/dev/null || true)"
        _project_dir="$(pwd)"
        if [ -n "$_stop_msg" ] && [ -d "$_project_dir/.codex" ]; then
            printf '%s' "$_stop_msg" > "$_project_dir/.codex/stop-hook.message.txt"
        fi
        printf '{"continue":false}\n'
        ;;
    *)
        bash "$_dispatch" "$@" 2>&1 || true
        ;;
esac

exit 0
