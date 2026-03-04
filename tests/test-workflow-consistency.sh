#!/bin/sh
# test-workflow-consistency.sh — Verify shared sections between workflow.md and workflow-full.md
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
FULL="$SCRIPT_DIR/../.baton/workflow-full.md"
FAIL=0

extract_section() {
    awk -v sect="### $2" 'BEGIN{f=0} $0==sect{f=1} f && /^---$/{exit} f && /^### / && $0!=sect{exit} f{print}' "$1"
}

for section in "Rules" "Session handoff" "Parallel sessions (optional)"; do
    A="$(extract_section "$SLIM" "$section")"
    B="$(extract_section "$FULL" "$section")"
    if [ "$A" != "$B" ]; then
        echo "DRIFT: '$section' differs between workflow.md and workflow-full.md"
        FAIL=1
    else
        echo "OK: '$section' is consistent"
    fi
done

# --- Shared header consistency: first block (up to first ---) should match ---
echo ""
echo "Checking shared header (before first ---)..."
HEAD_SLIM="$(awk '/^---$/{exit} {print}' "$SLIM")"
HEAD_FULL="$(awk '/^---$/{exit} {print}' "$FULL")"
if [ "$HEAD_SLIM" != "$HEAD_FULL" ]; then
    echo "DRIFT: header block differs between workflow.md and workflow-full.md"
    FAIL=1
else
    echo "OK: header block is consistent"
fi

# --- find_plan consistency: all 4 scripts must find plan.md the same way ---
echo ""
echo "Checking find_plan consistency across hook scripts..."

# Extract the walk-up loop logic from each script (core algorithm only)
extract_walk_up() {
    # Normalize: strip comments, blank lines, function wrapper, variable names
    sed -n '/while true/,/done/p' "$1" | sed 's/#.*//' | sed '/^$/d' | sed 's/^[[:space:]]*//'
}

WL="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/write-lock.sh")"
PG="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/phase-guide.sh")"
SG="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/stop-guard.sh")"
BG="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/bash-guard.sh")"

# phase-guide and stop-guard should be identical (both inline, same structure)
if [ "$PG" != "$SG" ]; then
    echo "DRIFT: find_plan loop differs between phase-guide.sh and stop-guard.sh"
    FAIL=1
else
    echo "OK: find_plan loop consistent (phase-guide.sh = stop-guard.sh)"
fi

# All must contain the core algorithm elements
for script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh; do
    path="$SCRIPT_DIR/../.baton/hooks/$script"
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

# --- Flow line consistency: Scenario A and B must match ---
echo ""
echo "Checking Flow line consistency..."
GUIDE="$SCRIPT_DIR/../.baton/hooks/phase-guide.sh"

for scenario in "Scenario A" "Scenario B"; do
    LINE_SLIM="$(grep -m1 "$scenario" "$SLIM" 2>/dev/null || true)"
    LINE_FULL="$(grep -m1 "$scenario" "$FULL" 2>/dev/null || true)"
    if [ -z "$LINE_SLIM" ] && [ -z "$LINE_FULL" ]; then
        echo "WARN: '$scenario' not found in either file"
    elif [ "$LINE_SLIM" != "$LINE_FULL" ]; then
        echo "DRIFT: '$scenario' line differs between workflow.md and workflow-full.md"
        FAIL=1
    else
        echo "OK: '$scenario' line is consistent"
    fi
done

# --- phase-guide.sh keyword cross-validation ---
echo ""
echo "Checking phase-guide.sh keywords in workflow-full.md..."

# RESEARCH phase keywords
for kw in "RESEARCH" "file:line" "subagent" "批注区"; do
    if grep -q "$kw" "$GUIDE" && ! grep -q "$kw" "$FULL"; then
        echo "DRIFT: phase-guide.sh mentions '$kw' but workflow-full.md does not"
        FAIL=1
    else
        echo "OK: keyword '$kw' consistent"
    fi
done

# IMPLEMENT phase keywords
for kw in "typecheck" "BATON:GO" "3 times"; do
    if grep -q "$kw" "$GUIDE" && ! grep -q "$kw" "$FULL"; then
        echo "DRIFT: phase-guide.sh mentions '$kw' but workflow-full.md does not"
        FAIL=1
    else
        echo "OK: keyword '$kw' consistent"
    fi
done

# --- 批注区 rule consistency ---
echo ""
echo "Checking 批注区 rule consistency..."
if grep -q "批注区" "$SLIM" && grep -q "批注区" "$FULL"; then
    echo "OK: 批注区 mentioned in both workflow files"
else
    echo "DRIFT: 批注区 not consistently mentioned in both workflow files"
    FAIL=1
fi

# --- Complexity Calibration consistency ---
echo ""
echo "Checking Complexity Calibration consistency..."
if grep -q "Complexity Calibration" "$SLIM" && grep -q "Complexity Calibration" "$FULL"; then
    echo "OK: Complexity Calibration in both workflow files"
else
    echo "DRIFT: Complexity Calibration not consistently present"
    FAIL=1
fi
for level in "Trivial" "Small" "Medium" "Large"; do
    if grep -q "$level" "$SLIM" && grep -q "$level" "$FULL"; then
        echo "OK: complexity level '$level' in both files"
    else
        echo "DRIFT: complexity level '$level' not consistently present"
        FAIL=1
    fi
done

# --- Anti-sycophancy line consistency ---
echo ""
echo "Checking anti-sycophancy line consistency..."
SYCO="accuracy, not comfort"
if grep -q "$SYCO" "$SLIM" && grep -q "$SYCO" "$FULL"; then
    echo "OK: anti-sycophancy line in both workflow files"
else
    echo "DRIFT: anti-sycophancy line not consistently present"
    FAIL=1
fi

# --- Self-Review keyword consistency (phase-guide ↔ workflow-full) ---
echo ""
echo "Checking Self-Review keyword consistency..."
if grep -q "Self-Review" "$GUIDE" && grep -q "Self-Review" "$FULL"; then
    echo "OK: Self-Review in both phase-guide.sh and workflow-full.md"
else
    echo "DRIFT: Self-Review not consistent between phase-guide.sh and workflow-full.md"
    FAIL=1
fi

# --- Retrospective keyword consistency ---
echo ""
echo "Checking Retrospective keyword consistency..."
STOP="$SCRIPT_DIR/../.baton/hooks/stop-guard.sh"
if grep -q "Retrospective" "$FULL" && grep -q "Retrospective" "$STOP"; then
    echo "OK: Retrospective in both workflow-full.md and stop-guard.sh"
else
    echo "DRIFT: Retrospective not consistent between workflow-full.md and stop-guard.sh"
    FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "FAILED: consistency check detected drift"
    exit 1
else
    echo ""
    echo "ALL CONSISTENT"
    exit 0
fi