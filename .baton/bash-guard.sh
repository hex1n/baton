#!/bin/sh
# bash-guard.sh — Advisory: warn about potential file writes when plan locked
# Version: 2.0
# Hook: PreToolUse (Bash)
# Always exit 0 — never blocks, only warns

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON bash-guard: unexpected error, skipping check" >&2; exit 0' HUP INT TERM

PLAN_NAME="${BATON_PLAN:-plan.md}"
# SYNCED: find_plan — same algorithm in write-lock.sh, phase-guide.sh, stop-guard.sh
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"; [ "$p" = "$d" ] && break; d="$p"
done

[ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null && exit 0

if [ ! -t 0 ]; then
    STDIN="$(cat 2>/dev/null || true)"
    if command -v jq >/dev/null 2>&1; then
        CMD="$(printf '%s' "$STDIN" | jq -r '.tool_input.command // empty' 2>/dev/null)"
    else
        CMD="$(printf '%s' "$STDIN" | awk -F'"' '{
            for(i=1;i<=NF;i++) if($i=="command") { print $(i+2); exit }
        }')"
    fi
    [ -z "${CMD:-}" ] && exit 0
    case "$CMD" in
        *">> "*|*"> "*|*"tee "*|*"sed -i"*|*"cp "*|*"mv "*)
            echo "⚠️ Bash guard: plan not unlocked, but command may write files" >&2
            ;;
    esac
fi
exit 0
