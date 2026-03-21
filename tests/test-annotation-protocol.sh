#!/bin/bash
# test-annotation-protocol.sh — Verify annotation protocol consistency across documents
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/constitution.md"
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
echo "=== Legacy explicit annotation types removed ==="

for marker in '\[NOTE\]' '\[Q\]' '\[CHANGE\]' '\[DEEPER\]' '\[MISSING\]' '\[RESEARCH-GAP\]'; do
    check_not "$SLIM" "$marker" "constitution.md does not contain $marker"
done

# ============================================================
echo ""
echo "=== Annotation protocol references in skills ==="

check "$RESEARCH_SKILL" '\[PAUSE\]' "baton-research mentions [PAUSE]"

# ============================================================
echo ""
echo "=== Core principles present in constitution.md ==="

check "$SLIM" "evidence" "constitution.md mentions evidence"

# ============================================================
echo ""
echo "=== Fork-context self-sufficiency guards ==="

check_not "$RESEARCH_SKILL" "live in .workflow\.md." "baton-research no longer delegates to constitution.md"

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
