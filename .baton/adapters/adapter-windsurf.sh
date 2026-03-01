#!/bin/sh
# adapter-windsurf.sh — Extract file_path from Windsurf edits array, forward to write-lock
# Windsurf may put file_path in .tool_info.file_path or .tool_info.edits[0].file_path

if [ ! -t 0 ]; then
    STDIN="$(cat 2>/dev/null || true)"
    if command -v jq >/dev/null 2>&1; then
        FILE_PATH="$(printf '%s' "$STDIN" | jq -r \
          '.tool_info.file_path // .tool_info.edits[0].file_path // empty' 2>/dev/null)"
    else
        FILE_PATH="$(printf '%s' "$STDIN" | awk -F'"' \
          '{ for(i=1;i<=NF;i++) if($i=="file_path") { print $(i+2); exit } }')"
    fi
    if [ -z "$FILE_PATH" ]; then
        echo "⚠️ Windsurf adapter: could not extract file path; allowing (fail-open)" >&2
        exit 0
    fi
    BATON_TARGET="$FILE_PATH" exec sh "$(dirname "$0")/../write-lock.sh" </dev/null
fi
