#!/bin/sh
# adapter-copilot.sh — Translate write-lock exit code to GitHub Copilot JSON protocol
# Copilot expects: {"permissionDecision":"allow"} or {"permissionDecision":"deny","permissionDecisionReason":"..."}

RESULT=$(sh "$(dirname "$0")/../write-lock.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    printf '{"permissionDecision":"allow"}\n'
else
    REASON=$(printf '%s' "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"permissionDecision":"deny","permissionDecisionReason":"%s"}\n' "$REASON"
fi