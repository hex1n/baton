#!/bin/sh
# adapter-cline-taskcomplete.sh — Translate completion-check result to Cline JSON protocol
# Cline expects: {"cancel":false} or {"cancel":true,"errorMessage":"..."}

RESULT=$(sh "$(dirname "$0")/../hooks/completion-check.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 2 ]; then
    MSG=$(printf '%s' "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"cancel":true,"errorMessage":"%s"}\n' "$MSG"
else
    printf '{"cancel":false}\n'
fi
