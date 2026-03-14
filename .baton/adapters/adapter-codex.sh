#!/usr/bin/env bash
# adapter-codex.sh — Translate Baton hook stderr to Codex stdout protocol
# Codex SessionStart reads plain text stdout as additionalContext (DeveloperInstructions)
# Codex Stop reads stdout similarly but is purely informational
#
# Baton capability: rules + guidance only (Codex)
#   Available signals: phase-guide (SessionStart), stop-guard (Stop) — advisory only
#   Not available: write-lock (no PreToolUse hard gate), bash-guard (no PreToolUse),
#     post-write-tracker, completion-check, failure-tracker, subagent-context, pre-compact
#   Note: Hard gates (write-lock, bash-guard) are not available on Codex.
#     Codex sandbox and human approval controls provide separate safety layers.
#
# Usage: adapter-codex.sh <phase-guide|stop-guard>
# Stdin: JSON from Codex (passed through to hook but typically unused)
# Stdout: hook's stderr output (Codex injects as context)

HOOK_NAME="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
HOOK_DIR="$SCRIPT_DIR/../hooks"

case "$HOOK_NAME" in
    phase-guide)  HOOK_SCRIPT="$HOOK_DIR/phase-guide.sh" ;;
    stop-guard)   HOOK_SCRIPT="$HOOK_DIR/stop-guard.sh" ;;
    *)
        echo "adapter-codex: unknown hook '$HOOK_NAME'" >&2
        exit 1
        ;;
esac

if [ ! -f "$HOOK_SCRIPT" ]; then
    echo "adapter-codex: hook script not found: $HOOK_SCRIPT" >&2
    exit 1
fi

# Baton hooks output to stderr (for Claude Code which displays stderr to AI).
# Codex reads stdout as additionalContext. Redirect stderr->stdout.
RESULT=$(bash "$HOOK_SCRIPT" 2>&1)
EXIT_CODE=$?

# Prepend capability tier statement so Codex always sees enforcement level
TIER_HEADER="[Baton capability: rules + guidance only (Codex)] Hard gates (write-lock, bash-guard) are not available. Enforcement relies on rules and guidance."

if [ -n "$RESULT" ]; then
    printf '%s\n%s\n' "$TIER_HEADER" "$RESULT"
else
    printf '%s\n' "$TIER_HEADER"
fi

exit $EXIT_CODE
