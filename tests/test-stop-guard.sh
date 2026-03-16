#!/bin/bash
# test-stop-guard.sh — Tests for stop-guard.sh v3 (Stop hook)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUARD="$SCRIPT_DIR/../.baton/hooks/stop-guard.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_guard() {
    # Run stop-guard.sh from given directory, capture stderr (output)
    local dir="$1"
    (cd "$dir" && bash "$GUARD" 2>&1 1>/dev/null)
}

run_guard_exit() {
    # Run stop-guard.sh and return exit code
    local dir="$1"
    local code
    (cd "$dir" && bash "$GUARD" 2>/dev/null)
    code=$?
    echo "$code"
}

assert_exit_zero() {
    local dir="$1" desc="$2"
    TOTAL=$((TOTAL + 1))
    if (cd "$dir" && bash "$GUARD" 2>/dev/null); then
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
## Todo
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
echo "=== Test 5: plan + GO, all done → finish workflow reminder ==="
d="$tmp/t5" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [x] Step 2: Done
- [x] Step 3: Done
EOF
assert_output_contains "$d" "Todo items complete" "shows completion message"
assert_output_contains "$d" "FINISH phase" "shows FINISH phase"
assert_output_contains "$d" "Retrospective" "suggests writing Retrospective"
assert_output_contains "$d" "test suite" "mentions full test suite"
assert_output_contains "$d" "branch disposition" "mentions branch disposition"
assert_output_contains "$d" "BATON:COMPLETE" "mentions COMPLETE marker"
assert_output_contains "$d" "Annotation Log" "mentions Annotation Log value"
assert_exit_zero "$d" "exit 0 when all complete"

# ============================================================
echo ""
echo "=== Test 6: BATON_PLAN custom plan file name ==="
d="$tmp/t6" && mkdir -p "$d"
cat > "$d/custom-plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
# Default plan.md doesn't exist → silent
assert_output_empty "$d" "default plan.md not found → silent"
# Custom plan → shows remaining
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && BATON_PLAN=custom-plan.md bash "$GUARD" 2>&1 1>/dev/null)"
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
## Todo
- [ ] Step 1: Not done
EOF
assert_output_contains "$d/project/src/components" "1 remaining" "walk-up finds plan.md in parent"
assert_exit_zero "$d/project/src/components" "exit 0 from subdirectory"

# ============================================================
echo ""
echo "=== Test 8: Walk-up finds plan-*.md from subdirectory ==="
d="$tmp/t8" && mkdir -p "$d/src/deep"
cat > "$d/plan-feature.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1: do something
EOF
# Run from subdirectory — should find plan-feature.md and detect remaining Todo
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d/src/deep" && bash "$GUARD" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "remaining"; then
    echo "  pass: walk-up finds plan-feature.md from subdirectory, detects remaining Todo"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected 'remaining' in output for plan-feature.md walk-up"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 9: Single unchecked item ==="
d="$tmp/t9" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1: Only task
EOF
assert_output_contains "$d" "0/1" "shows 0/1 done"
assert_output_contains "$d" "1 remaining" "shows 1 remaining"
assert_exit_zero "$d" "exit 0"

# ============================================================
echo ""
echo "=== Test 10: Mixed content — only counts TODO lines ==="
d="$tmp/t10" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->

## Description
Some text about the plan.

## Todo
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
echo "=== Test 11: All done → finish workflow with 3-question Retrospective prompt ==="
d="$tmp/t11" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [x] Step 2: Done
EOF
assert_output_contains "$d" "FINISH phase" "finish workflow shows FINISH phase"
assert_output_contains "$d" "plan get wrong" "Retrospective prompt includes 'plan get wrong'"
assert_output_contains "$d" "surprised" "Retrospective prompt includes 'surprised'"
assert_output_contains "$d" "research differently" "Retrospective prompt includes 'research differently'"

# ============================================================
echo ""
echo "=== Test 12: Multi-plan advisory — stop-guard still works ==="
d="$tmp/t12" && mkdir -p "$d"
echo "# Other" > "$d/plan-feature.md"
sleep 0.1  # ensure plan.md is newer by mtime
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
# stop-guard is advisory (exit 0 always) — multi-plan doesn't block it
assert_output_contains "$d" "remaining" "multi-plan → stop-guard still detects remaining"
assert_exit_zero "$d" "multi-plan → still exit 0"

# ============================================================
echo ""
echo "=== Test 13: Section-aware counting — items outside ## Todo ignored ==="
d="$tmp/t13" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
## Approach
- [ ] This is NOT a Todo item (in wrong section)
## Todo
- [x] Step 1: Done
- [ ] Step 2: Not done
## Notes
- [ ] This is also NOT a Todo item
EOF
assert_output_contains "$d" "1/2" "only counts items under ## Todo"
assert_output_contains "$d" "1 remaining" "ignores items in other sections"
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
