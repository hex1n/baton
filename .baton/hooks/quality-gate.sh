#!/usr/bin/env bash
# quality-gate.sh — Advisory hook: checks for self-challenge evidence
# Version: 1.0
# Hook: PostToolUse (fires after Write/Edit to plan/research files)
#
# Checks that plan/research files contain ## Self-Challenge section
# with sufficient depth (≥3 content lines).
# Advisory only — always exits 0. Outputs reminders to stderr.

trap 'exit 0' HUP INT TERM

# Only check plan and research files
TARGET="${BATON_TARGET:-}"
[ -z "$TARGET" ] && exit 0

case "$(basename "$TARGET")" in
    plan*.md|plan.md) FILE_TYPE="Plan" ;;
    research*.md|research.md) FILE_TYPE="Research" ;;
    *) exit 0 ;;
esac

[ ! -f "$TARGET" ] && exit 0

# Check for Self-Challenge section
if ! grep -q '^## Self-Challenge' "$TARGET" 2>/dev/null; then
    echo "⚠️ $FILE_TYPE has no ## Self-Challenge section. Before presenting:" >&2
    echo "   - Is this the best approach, or the first one you thought of?" >&2
    echo "   - What assumptions haven't you verified?" >&2
    echo "   - What would a skeptic challenge first?" >&2
    exit 0
fi

# Check self-challenge depth
_sc_lines="$(awk '
    /^## Self-Challenge/ { in_sc=1; next }
    in_sc && /^## / { exit }
    in_sc && /[^[:space:]]/ { count++ }
    END { print (count+0) }
' "$TARGET")" || _sc_lines=0

if [ "$_sc_lines" -lt 3 ] 2>/dev/null; then
    echo "⚠️ ## Self-Challenge has <3 content lines — may be too shallow." >&2
fi

exit 0
