#!/bin/sh
# adapter-cline.sh — Translate write-lock exit code to Cline JSON protocol
# Cline expects: {"cancel":false} or {"cancel":true,"errorMessage":"..."}

RESULT=$(sh "$(dirname "$0")/../write-lock.sh" 2>&1)
EXIT_CODE=$?
if [ $EXIT_CODE -eq 0 ]; then
    printf '{"cancel":false}'
else
    MSG=$(printf '%s' "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"cancel":true,"errorMessage":"%s"}' "$MSG"
fi
