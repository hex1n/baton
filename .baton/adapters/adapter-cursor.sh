#!/bin/sh
# adapter-cursor.sh — Translate write-lock exit code to Cursor JSON protocol
# Cursor expects: {"decision":"allow"} or {"decision":"deny","reason":"..."}

RESULT=$(bash "$(dirname "$0")/../hooks/write-lock.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    printf '{"decision":"allow"}\n'
    exit 0
else
    REASON=$(printf '%s' "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"decision":"deny","reason":"%s"}\n' "$REASON"
    exit 2
fi