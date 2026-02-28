#!/bin/sh
# write-lock.sh — Block source code writes until plan.md contains <!-- GO -->
#
# Hook: PreToolUse (Edit|Write|MultiEdit|CreateFile)
# Unlock: Add <!-- GO --> anywhere in plan.md
# Re-lock: Remove <!-- GO -->
# Always allowed: *.md files
#
# Target path resolution: $1 > $BATON_TARGET > stdin JSON (best-effort)

# --- Emergency bypass ---
if [ "${BATON_BYPASS:-}" = "1" ]; then
    echo "⚠️ Write lock bypassed (BATON_BYPASS=1)" >&2
    exit 0
fi

# --- Resolve target path ---
TARGET="${1:-${BATON_TARGET:-}}"

if [ -z "$TARGET" ] && [ ! -t 0 ]; then
    STDIN="$(cat 2>/dev/null || true)"
    if [ -n "$STDIN" ]; then
        if command -v python3 >/dev/null 2>&1; then
            TARGET="$(printf '%s' "$STDIN" | python3 -c "
import sys,json
try:
    d=json.load(sys.stdin)
    ti=d.get('tool_input',d.get('input',{}))
    if isinstance(ti,dict):
        print(ti.get('file_path',ti.get('path',ti.get('filepath',''))))
except: pass
" 2>/dev/null)"
        else
            TARGET="$(printf '%s' "$STDIN" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
        fi
    fi
fi

# Can't determine target → fail-open (with warning)
if [ -z "$TARGET" ]; then
    echo "⚠️ Write lock: could not determine target path; allowing (fail-open)" >&2
    exit 0
fi

# --- Markdown is always allowed ---
case "$TARGET" in
    *.md|*.MD|*.markdown) exit 0 ;;
esac

# --- Find plan.md by walking up from cwd ---
find_plan() {
    d="$(pwd)"
    while true; do
        [ -f "$d/plan.md" ] && { echo "$d/plan.md"; return; }
        p="$(dirname "$d")"
        [ "$p" = "$d" ] && return
        d="$p"
    done
}

PLAN="$(find_plan)"

# No plan.md found → block (still in research phase)
if [ -z "$PLAN" ]; then
    echo "🔒 Blocked: no plan.md found. Complete research and planning first." >&2
    exit 1
fi

# plan.md has GO marker → allow
if grep -q '<!-- GO -->' "$PLAN" 2>/dev/null; then
    exit 0
fi

echo "🔒 Blocked: plan.md exists but not unlocked. Add <!-- GO --> to plan.md when ready to implement." >&2
exit 1
