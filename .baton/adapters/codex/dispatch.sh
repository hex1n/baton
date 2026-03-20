#!/usr/bin/env bash
# dispatch-codex.sh — Codex adapter for dispatch.sh
# SessionStart expects hook JSON on stdout.
# Stop expects valid Stop-hook JSON on stdout, so human-readable reminder text
# must stay off the protocol channel.
set -eu

_event="${1:-}"
_dir="$(cd "$(dirname "$0")" && pwd)"
_dispatch="$_dir/../../hooks/dispatch.sh"

_TIER_HEADER="[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available. Enforcement relies on rules and guidance."

case "$_event" in
    SessionStart)
        # Close stdin — Codex may not send EOF, causing dispatch.sh's `cat` to hang
        # Prepend tier header so Codex knows enforcement mode at session start
        printf '%s\n' "$_TIER_HEADER"
        bash "$_dispatch" "$@" </dev/null || true
        ;;
    Stop)
        _stop_msg="$(bash "$_dispatch" "$@" </dev/null 2>&1 1>/dev/null || true)"
        _project_dir="$(pwd)"
        if [ -n "$_stop_msg" ] && [ -d "$_project_dir/.codex" ]; then
            printf '%s' "$_stop_msg" > "$_project_dir/.codex/stop-hook.message.txt"
        fi
        printf '{"continue":false}\n'
        ;;
    *)
        bash "$_dispatch" "$@" </dev/null 2>&1 || true
        ;;
esac

exit 0
