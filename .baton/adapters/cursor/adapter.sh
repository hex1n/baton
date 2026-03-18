#!/bin/sh
# adapter-cursor.sh — Translate write-lock exit code to Cursor JSON protocol
# Cursor expects: {"decision":"allow"} or {"decision":"deny","reason":"..."}
#
# Baton capability: reduced enforcement (Cursor)
#   Available signals: write-lock (hard block via this adapter), phase-guide,
#     bash-guard, subagent-context, pre-compact
#   Reduced/missing: post-write-tracker (no write-set drift warning),
#     stop-guard (no session-end reminders), completion-check,
#     failure-tracker, retrospective enforcement

RESULT=$(bash "$(dirname "$0")/../../hooks/write-lock.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    # Extract additionalContext from write-lock hookSpecificOutput if present
    CONTEXT=""
    if printf '%s' "$RESULT" | grep -q 'additionalContext'; then
        if command -v jq >/dev/null 2>&1; then
            CONTEXT=$(printf '%s' "$RESULT" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null)
        fi
        if [ -z "$CONTEXT" ]; then
            CONTEXT="Baton: write-gate open — verify file is in approved write set."
        fi
    fi
    if [ -n "$CONTEXT" ]; then
        CONTEXT_ESC=$(printf '%s' "$CONTEXT" | sed 's/\\/\\\\/g; s/"/\\"/g')
        printf '{"decision":"allow","context":"[Baton capability: reduced enforcement (Cursor)] %s"}\n' "$CONTEXT_ESC"
    else
        printf '{"decision":"allow"}\n'
    fi
    exit 0
else
    REASON=$(printf '%s' "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"decision":"deny","reason":"[Baton capability: reduced enforcement (Cursor)] %s"}\n' "$REASON"
    exit 2
fi
