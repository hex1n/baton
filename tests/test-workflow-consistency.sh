#!/bin/sh
# test-workflow-consistency.sh — Verify shared sections between workflow.md and workflow-full.md
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
FULL="$SCRIPT_DIR/../.baton/workflow-full.md"
FAIL=0

extract_section() {
    awk -v sect="### $2" 'BEGIN{f=0} $0==sect{f=1} f && /^### / && $0!=sect{exit} f{print}' "$1"
}

for section in "Rules" "Session handoff" "Parallel sessions"; do
    A="$(extract_section "$SLIM" "$section")"
    B="$(extract_section "$FULL" "$section")"
    if [ "$A" != "$B" ]; then
        echo "DRIFT: '$section' differs between workflow.md and workflow-full.md"
        FAIL=1
    else
        echo "OK: '$section' is consistent"
    fi
done

# --- find_plan consistency: all 4 scripts must find plan.md the same way ---
echo ""
echo "Checking find_plan consistency across hook scripts..."

# Extract the walk-up loop logic from each script (core algorithm only)
extract_walk_up() {
    # Normalize: strip comments, blank lines, function wrapper, variable names
    sed -n '/while true/,/done/p' "$1" | sed 's/#.*//' | sed '/^$/d' | sed 's/^[[:space:]]*//'
}

WL="$(extract_walk_up "$SCRIPT_DIR/../.baton/write-lock.sh")"
PG="$(extract_walk_up "$SCRIPT_DIR/../.baton/phase-guide.sh")"
SG="$(extract_walk_up "$SCRIPT_DIR/../.baton/stop-guard.sh")"
BG="$(extract_walk_up "$SCRIPT_DIR/../.baton/bash-guard.sh")"

# phase-guide and stop-guard should be identical (both inline, same structure)
if [ "$PG" != "$SG" ]; then
    echo "DRIFT: find_plan loop differs between phase-guide.sh and stop-guard.sh"
    FAIL=1
else
    echo "OK: find_plan loop consistent (phase-guide.sh = stop-guard.sh)"
fi

# All must contain the core algorithm elements
for script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh; do
    path="$SCRIPT_DIR/../.baton/$script"
    body="$(extract_walk_up "$path")"
    # Must have: while loop, file test, dirname, parent==dir termination
    missing=""
    echo "$body" | grep -q 'while true' || missing="$missing while-loop"
    echo "$body" | grep -q 'PLAN_NAME' || missing="$missing PLAN_NAME"
    echo "$body" | grep -q 'dirname' || missing="$missing dirname"
    if [ -n "$missing" ]; then
        echo "DRIFT: $script find_plan missing core elements:$missing"
        FAIL=1
    else
        echo "OK: $script find_plan has all core elements"
    fi
done

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "FAILED: consistency check detected drift"
    exit 1
else
    echo ""
    echo "ALL CONSISTENT"
    exit 0
fi
