#!/bin/bash
# test-annotation-protocol.sh — Verify annotation protocol consistency across documents
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
PLAN_SKILL="$SCRIPT_DIR/../.baton/skills/baton-plan/SKILL.md"
RESEARCH_SKILL="$SCRIPT_DIR/../.baton/skills/baton-research/SKILL.md"
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
echo "=== Direction γ markers in workflow.md ==="

check "$SLIM" '\[PAUSE\]' "workflow.md contains [PAUSE]"
check "$SLIM" "infers intent from content" "workflow.md mentions intent inference"

# ============================================================
echo ""
echo "=== Direction γ markers migrated to skills ==="

check "$PLAN_SKILL" "infers intent" "baton-plan mentions intent inference"
check "$PLAN_SKILL" "free-text" "baton-plan documents free-text default"
check "$PLAN_SKILL" "Consequence detection" "baton-plan documents consequence detection"
check "$RESEARCH_SKILL" "infers intent" "baton-research mentions intent inference"
check "$RESEARCH_SKILL" "free-text" "baton-research documents free-text default"
check "$RESEARCH_SKILL" "Consequence detection" "baton-research documents consequence detection"

# ============================================================
echo ""
echo "=== Legacy explicit annotation types removed ==="

for marker in '\[NOTE\]' '\[Q\]' '\[CHANGE\]' '\[DEEPER\]' '\[MISSING\]' '\[RESEARCH-GAP\]'; do
    check_not "$SLIM" "$marker" "workflow.md does not contain $marker"
done

# ============================================================
echo ""
echo "=== Annotation protocol detailed coverage in skills ==="

check "$PLAN_SKILL" "Annotation Log" "baton-plan has Annotation Log section"
check "$PLAN_SKILL" "Round 1" "baton-plan has Annotation Log example"
check "$PLAN_SKILL" "Annotation Log Format" "baton-plan has annotation log format section"
check "$PLAN_SKILL" '\[PAUSE\]' "baton-plan mentions [PAUSE]"
check "$RESEARCH_SKILL" "Annotation Log" "baton-research has Annotation Log section"
check "$RESEARCH_SKILL" '\[PAUSE\]' "baton-research mentions [PAUSE]"

# ============================================================
echo ""
echo "=== Plan analysis concepts in baton-plan skill ==="

check "$PLAN_SKILL" "Approach Analysis" "baton-plan has approach analysis section"
check "$PLAN_SKILL" "fundamental constraints" "baton-plan mentions fundamental constraints"
check "$PLAN_SKILL" "Fundamental Problems" "baton-plan has fundamental problem handling"

# ============================================================
echo ""
echo "=== Core principles present in workflow.md ==="

check "$SLIM" "not always right" "workflow.md contains push-back principle"
check "$SLIM" "evidence" "workflow.md mentions evidence"

# ============================================================
echo ""
echo "=== Cross-cutting annotation rules in workflow.md ==="

check "$SLIM" "write the conclusion back to the document body" "workflow.md has analysis write-back rule"
check "$SLIM" "re-evaluate and update the plan immediately" "workflow.md has approach re-evaluation rule"
check "$SLIM" "remove the raw text from" "workflow.md has annotation cleanup rule"

# ============================================================
echo ""
echo "=== Group 3: fork-context self-sufficiency guards ==="

check_not "$RESEARCH_SKILL" "live in .workflow\.md." "baton-research no longer delegates to workflow.md"
check "$RESEARCH_SKILL" "document body" "baton-research has inlined analysis write-back rule"

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
