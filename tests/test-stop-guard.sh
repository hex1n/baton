#!/bin/bash
# test-stop-guard.sh — Tests for stop-guard.sh (Stop hook)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/../.baton/stop-guard.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_guard() {
    # Run stop-guard.sh from given directory, capture stderr (output)
    local dir="$1"
    (cd "$dir" && sh "$GUARD" 2>&1 1>/dev/null)
}

run_guard_exit() {
    # Run stop-guard.sh and return exit code
    local dir="$1"
    local code
    (cd "$dir" && sh "$GUARD" 2>/dev/null)
    code=$?
    echo "$code"
}

assert_exit_zero() {
    local dir="$1" desc="$2"
    TOTAL=$((TOTAL + 1))
    if (cd "$dir" && sh "$GUARD" 2>/dev/null); then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected exit 0)"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_contains() {
    local dir="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    local output
    output="$(run_guard "$dir")"
    if echo "$output" | grep -q "$pattern"; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected '$pattern' in output)"
        echo "    got: $output"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_empty() {
    local dir="$1" desc="$2"
    TOTAL=$((TOTAL + 1))
    local output
    output="$(run_guard "$dir")"
    if [ -z "$output" ]; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected empty output)"
        echo "    got: $output"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test 1: No plan.md → silent exit 0 ==="
d="$tmp/t1" && mkdir -p "$d"
assert_output_empty "$d" "no output when no plan.md"
assert_exit_zero "$d" "exit 0 when no plan.md"

# ============================================================
echo ""
echo "=== Test 2: plan.md without GO → silent exit 0 ==="
d="$tmp/t2" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
- [ ] Step 1: Do something
- [ ] Step 2: Do another thing
EOF
assert_output_empty "$d" "no output when plan has no GO"
assert_exit_zero "$d" "exit 0 when plan has no GO"

# ============================================================
echo ""
echo "=== Test 3: plan + GO, no TODOs → silent exit 0 ==="
d="$tmp/t3" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
Some implementation notes, no checklist.
EOF
assert_output_empty "$d" "no output when no TODOs"
assert_exit_zero "$d" "exit 0 when no TODOs"

# ============================================================
echo ""
echo "=== Test 4: plan + GO, 3/5 done → shows remaining ==="
d="$tmp/t4" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
- [x] Step 1: Done
- [x] Step 2: Done
- [x] Step 3: Done
- [ ] Step 4: Not done
- [ ] Step 5: Not done
EOF
assert_output_contains "$d" "3/5" "shows 3/5 done"
assert_output_contains "$d" "2 remaining" "shows 2 remaining"
assert_output_contains "$d" "resume" "suggests resume from checklist"
assert_output_contains "$d" "Lessons Learned" "suggests Lessons Learned section"
assert_exit_zero "$d" "exit 0 even with remaining items"

# ============================================================
echo ""
echo "=== Test 5: plan + GO, all done → silent exit 0 ==="
d="$tmp/t5" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
- [x] Step 1: Done
- [x] Step 2: Done
- [x] Step 3: Done
EOF
assert_output_empty "$d" "no output when all TODOs complete"
assert_exit_zero "$d" "exit 0 when all complete"

# ============================================================
echo ""
echo "=== Test 6: BATON_PLAN custom plan file name ==="
d="$tmp/t6" && mkdir -p "$d"
cat > "$d/custom-plan.md" << 'EOF'
<!-- BATON:GO -->
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
# Default plan.md doesn't exist → silent
assert_output_empty "$d" "default plan.md not found → silent"
# Custom plan → shows remaining
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && BATON_PLAN=custom-plan.md sh "$GUARD" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "1 remaining"; then
    echo "  pass: BATON_PLAN=custom-plan.md → detects 1 remaining"
    PASS=$((PASS + 1))
else
    echo "  FAIL: BATON_PLAN should use custom plan file"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: Walk-up plan discovery ==="
d="$tmp/t7" && mkdir -p "$d/project/src/components"
cat > "$d/project/plan.md" << 'EOF'
<!-- BATON:GO -->
- [ ] Step 1: Not done
EOF
assert_output_contains "$d/project/src/components" "1 remaining" "walk-up finds plan.md in parent"
assert_exit_zero "$d/project/src/components" "exit 0 from subdirectory"

# ============================================================
echo ""
echo "=== Test 8: Single unchecked item ==="
d="$tmp/t8" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
- [ ] Step 1: Only task
EOF
assert_output_contains "$d" "0/1" "shows 0/1 done"
assert_output_contains "$d" "1 remaining" "shows 1 remaining"
assert_exit_zero "$d" "exit 0"

# ============================================================
echo ""
echo "=== Test 9: Mixed content — only counts TODO lines ==="
d="$tmp/t9" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->

## Description
Some text about the plan.

## TODO
- [x] Step 1: Done
- [ ] Step 2: Not done

## Notes
- This is a note (not a TODO)
- Another note
EOF
assert_output_contains "$d" "1/2" "counts only TODO-format lines"
assert_exit_zero "$d" "exit 0"

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
