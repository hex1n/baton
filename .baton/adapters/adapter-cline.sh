#!/bin/sh
# adapter-cline.sh — Translate write-lock exit code to Cline JSON protocol
# Cline expects: {"cancel":false} or {"cancel":true,"errorMessage":"..."}
# Filters by tool name: only write tools trigger write-lock check

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | grep -o '"tool":"[^"]*"' | head -1 | cut -d'"' -f4)

case "$TOOL" in
    write_to_file|replace_in_file|insert_content)
        RESULT=$(printf '%s' "$INPUT" | sh "$(dirname "$0")/../hooks/write-lock.sh" 2>&1)
        EXIT_CODE=$?
        if [ $EXIT_CODE -eq 0 ]; then
            printf '{"cancel":false}\n'
        else
            MSG=$(printf '%s' "$RESULT" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
            printf '{"cancel":true,"errorMessage":"%s"}\n' "$MSG"
        fi
        ;;
    *)
        printf '{"cancel":false}\n'
        ;;
esac