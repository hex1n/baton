#!/bin/bash
# test-phase-guide.sh — Tests for phase-guide.sh (SessionStart hook)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE="$SCRIPT_DIR/../.baton/phase-guide.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_guide() {
    # Run phase-guide.sh from given directory, capture stderr (guidance output)
    local dir="$1"
    (cd "$dir" && sh "$GUIDE" 2>&1 1>/dev/null)
}

run_guide_exit() {
    # Run phase-guide.sh and return exit code
    local dir="$1"
    (cd "$dir" && sh "$GUIDE" 2>/dev/null); echo $?
}

assert_output_contains() {
    local dir="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    local output
    output="$(run_guide "$dir")"
    if echo "$output" | grep -q "$pattern"; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected '$pattern' in output)"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_not_contains() {
    local dir="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    local output
    output="$(run_guide "$dir")"
    if echo "$output" | grep -q "$pattern"; then
        echo "  FAIL: $desc (unexpected '$pattern' in output)"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    fi
}

assert_exit_zero() {
    local dir="$1" desc="$2"
    TOTAL=$((TOTAL + 1))
    if (cd "$dir" && sh "$GUIDE" 2>/dev/null); then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected exit 0)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test 1: No plan.md → RESEARCH phase guidance ==="
d="$tmp/t1" && mkdir -p "$d"
assert_output_contains "$d" "RESEARCH" "outputs RESEARCH phase label"
assert_output_contains "$d" "research.md" "mentions research.md"
assert_output_contains "$d" "Scope" "mentions Scope section"
assert_output_contains "$d" "Bug fix" "mentions bug fix shortcut"
assert_output_contains "$d" "subagent" "mentions subagent strategy"
assert_exit_zero "$d" "always exit 0 (no plan)"

# ============================================================
echo ""
echo "=== Test 2: plan.md without GO → PLAN phase guidance ==="
d="$tmp/t2" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_output_contains "$d" "PLAN" "outputs PLAN phase label"
assert_output_contains "$d" "scope" "mentions scope declaration"
assert_output_contains "$d" "Verification" "mentions verification"
assert_output_contains "$d" "Self-review" "mentions self-review"
assert_output_contains "$d" "acceptance criteria" "mentions annotation exit checklist"
assert_output_contains "$d" "Goal.*Scope.*Approach" "mentions suggested plan structure"
assert_exit_zero "$d" "always exit 0 (plan, no GO)"

# ============================================================
echo ""
echo "=== Test 3: plan.md with GO → IMPLEMENT phase guidance ==="
d="$tmp/t3" && mkdir -p "$d"
echo "<!-- BATON:GO -->" > "$d/plan.md"
assert_output_contains "$d" "IMPLEMENT" "outputs IMPLEMENT phase label"
assert_output_contains "$d" "compact" "mentions /compact"
assert_output_contains "$d" "test suite" "mentions test suite"
assert_output_contains "$d" "Rollback" "mentions rollback strategy"
assert_exit_zero "$d" "always exit 0 (implement)"

# ============================================================
echo ""
echo "=== Test 4: plan.md with [x] completed tasks → archival reminder ==="
d="$tmp/t4" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
assert_output_contains "$d" "Stale" "detects stale plan with completed tasks"
assert_output_contains "$d" "Archive" "suggests archival"
assert_output_contains "$d" "plans/" "suggests plans/ directory"
assert_output_contains "$d" "Lessons Learned" "suggests keeping Lessons Learned section"
# Should still show PLAN phase guidance (no GO)
assert_output_contains "$d" "PLAN" "still shows phase guidance after archival notice"
assert_exit_zero "$d" "always exit 0 (archival detection)"

# ============================================================
echo ""
echo "=== Test 5: plan.md with GO and [x] → NO archival (active implementation) ==="
d="$tmp/t5" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
assert_output_not_contains "$d" "Stale" "no archival during active implementation"
assert_output_contains "$d" "IMPLEMENT" "shows IMPLEMENT phase"
assert_exit_zero "$d" "always exit 0"

# ============================================================
echo ""
echo "=== Test 6: BATON_PLAN custom plan file name ==="
d="$tmp/t6" && mkdir -p "$d"
echo "<!-- BATON:GO -->" > "$d/custom.md"
# Default → no plan found → RESEARCH
assert_output_contains "$d" "RESEARCH" "default plan name → RESEARCH (no plan.md)"
# Custom plan → IMPLEMENT
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && BATON_PLAN=custom.md sh "$GUIDE" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "IMPLEMENT"; then
    echo "  pass: BATON_PLAN=custom.md → IMPLEMENT guidance"
    PASS=$((PASS + 1))
else
    echo "  FAIL: BATON_PLAN should use custom plan file"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: Walk-up plan discovery ==="
d="$tmp/t7" && mkdir -p "$d/project/src/components"
echo "# Plan" > "$d/project/plan.md"
assert_output_contains "$d/project/src/components" "PLAN" "walk-up finds plan.md in parent"

# ============================================================
echo ""
echo "=== Test 8: Phase guidance mutually exclusive ==="
d="$tmp/t8" && mkdir -p "$d"
# RESEARCH phase should not mention IMPLEMENT or PLAN keywords from other phases
assert_output_not_contains "$d" "IMPLEMENT" "RESEARCH phase does not mention IMPLEMENT"

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
