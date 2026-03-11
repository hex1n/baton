#!/bin/bash
# test-annotation-protocol.sh — Verify annotation protocol consistency across documents
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
FULL="$SCRIPT_DIR/../.baton/workflow-full.md"
PASS=0
FAIL=0
TOTAL=0

check() {
    local file="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    if grep -q "$pattern" "$file"; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (pattern '$pattern' not found)"
        FAIL=$((FAIL + 1))
    fi
}

check_not() {
    local file="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    if grep -q "$pattern" "$file"; then
        echo "  FAIL: $desc (pattern '$pattern' should be absent)"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    fi
}

# ============================================================
echo "=== Direction γ markers present in both files ==="

check "$SLIM" '\[PAUSE\]' "workflow.md contains [PAUSE]"
check "$FULL" '\[PAUSE\]' "workflow-full.md contains [PAUSE]"
check "$SLIM" "infers intent from content" "workflow.md mentions intent inference"
check "$FULL" "infers intent from content" "workflow-full.md mentions intent inference"
check "$FULL" "Free-text is the default" "workflow-full.md documents free-text default"
check "$FULL" "Consequence detection" "workflow-full.md documents consequence detection"

# ============================================================
echo ""
echo "=== Legacy explicit annotation types removed ==="

for marker in '\[NOTE\]' '\[Q\]' '\[CHANGE\]' '\[DEEPER\]' '\[MISSING\]' '\[RESEARCH-GAP\]'; do
    check_not "$SLIM" "$marker" "workflow.md does not contain $marker"
    check_not "$FULL" "$marker" "workflow-full.md does not contain $marker"
done

# ============================================================
echo ""
echo "=== workflow-full.md has detailed annotation sections ==="

check "$FULL" "Annotation Log" "workflow-full.md has Annotation Log section"
check "$FULL" "Round 1" "workflow-full.md has Annotation Log example"
check "$FULL" "Annotation Format" "workflow-full.md has annotation format section"
check "$FULL" "Core Principles" "workflow-full.md has AI response principles"
check "$FULL" "\[PAUSE\] Handling" "workflow-full.md has [PAUSE] handling section"
check "$FULL" "Correct behavior:" "workflow-full.md has correct AI behavior examples"
check "$FULL" "Incorrect behavior:" "workflow-full.md has incorrect AI behavior examples"

# ============================================================
echo ""
echo "=== Core principles present in both files ==="

check "$SLIM" "not always right" "workflow.md contains push-back principle"
check "$FULL" "not always right" "workflow-full.md contains push-back principle"
check "$SLIM" "evidence" "workflow.md mentions evidence"
check "$FULL" "evidence" "workflow-full.md mentions evidence"

# ============================================================
echo ""
echo "=== Cross-cutting annotation rules in workflow.md ==="

check "$SLIM" "write the conclusion back to the document body" "workflow.md has analysis write-back rule"
check "$SLIM" "re-evaluate and update the plan immediately" "workflow.md has approach re-evaluation rule"
check "$SLIM" "remove the raw text from" "workflow.md has annotation cleanup rule"

# ============================================================
echo ""
echo "=== Plan analysis section in workflow-full.md ==="

check "$FULL" "Approach Analysis" "workflow-full.md has approach analysis section"
check "$FULL" "fundamental constraints" "workflow-full.md mentions fundamental constraints"
check "$FULL" "Fundamental Problems" "workflow-full.md has fundamental problem handling"

# ============================================================
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi
