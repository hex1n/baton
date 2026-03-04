#!/bin/bash
# test-new-hooks.sh — Tests for new hook scripts (post-write-tracker, subagent-context,
#                      completion-check, pre-compact)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON="$SCRIPT_DIR/../.baton/hooks"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_hook() {
    local hook="$1" dir="$2"
    shift 2
    (cd "$dir" && "$@" sh "$BATON/$hook" 2>&1 1>/dev/null) || true
}

assert_output_contains() {
    local output="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$output" | grep -q "$pattern"; then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected '$pattern')"
        FAIL=$((FAIL + 1))
    fi
}

assert_output_not_contains() {
    local output="$1" pattern="$2" desc="$3"
    TOTAL=$((TOTAL + 1))
    if echo "$output" | grep -q "$pattern"; then
        echo "  FAIL: $desc (unexpected '$pattern')"
        FAIL=$((FAIL + 1))
    else
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    fi
}

assert_exit_code() {
    local expected="$1" hook="$2" dir="$3"
    shift 3
    TOTAL=$((TOTAL + 1))
    local actual=0
    (cd "$dir" && env "$@" sh "$BATON/$hook" </dev/null 2>/dev/null 1>/dev/null) || actual=$?
    if [ "$actual" -eq "$expected" ]; then
        echo "  pass: exit code $actual == $expected"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: expected exit $expected, got $actual"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== post-write-tracker.sh ==="

echo "--- Test 1: File in plan → no warning ---"
d="$tmp/pwt1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Update src/app.ts\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && BATON_TARGET="src/app.ts" sh "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "file in plan → no warning"

echo "--- Test 2: File NOT in plan → warning ---"
d="$tmp/pwt2" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Update src/app.ts\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && BATON_TARGET="src/other.ts" sh "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "not mentioned" "file not in plan → warning"

echo "--- Test 3: Markdown file → no warning (always allowed) ---"
d="$tmp/pwt3" && mkdir -p "$d"
OUTPUT="$(cd "$d" && BATON_TARGET="research.md" sh "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "markdown always passes silently"

echo "--- Test 4: No plan → silent exit ---"
d="$tmp/pwt4" && mkdir -p "$d"
OUTPUT="$(cd "$d" && BATON_TARGET="src/app.ts" sh "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "no plan → silent exit"

echo "--- Test 5: BATON_BYPASS=1 → silent exit ---"
d="$tmp/pwt5" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && BATON_BYPASS=1 BATON_TARGET="src/app.ts" sh "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "bypass → silent exit"

# ============================================================
echo ""
echo "=== subagent-context.sh ==="

echo "--- Test 6: Plan with todos → outputs context ---"
d="$tmp/sc1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [ ] Step 2\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && sh "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "1/2" "shows progress count"
assert_output_contains "$OUTPUT" "Step" "shows todo items"

echo "--- Test 7: No plan → silent ---"
d="$tmp/sc2" && mkdir -p "$d"
OUTPUT="$(cd "$d" && sh "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "Baton plan" "no plan → silent"

echo "--- Test 8: Plan without GO → silent ---"
d="$tmp/sc3" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
OUTPUT="$(cd "$d" && sh "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "Baton plan" "no GO → silent"

# ============================================================
echo ""
echo "=== completion-check.sh ==="

echo "--- Test 9: All done + no Retrospective → exit 2 (block) ---"
d="$tmp/cc1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [x] Step 2\n' > "$d/plan.md"
assert_exit_code 2 "completion-check.sh" "$d"

echo "--- Test 10: All done + has Retrospective → exit 0 (allow) ---"
d="$tmp/cc2" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n## Retrospective\nLearnings here\n' > "$d/plan.md"
assert_exit_code 0 "completion-check.sh" "$d"

echo "--- Test 11: Not all done → exit 0 (allow, not enforced yet) ---"
d="$tmp/cc3" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [ ] Step 2\n' > "$d/plan.md"
assert_exit_code 0 "completion-check.sh" "$d"

echo "--- Test 12: No plan → exit 0 ---"
d="$tmp/cc4" && mkdir -p "$d"
assert_exit_code 0 "completion-check.sh" "$d"

echo "--- Test 13: BATON_BYPASS=1 → exit 0 ---"
d="$tmp/cc5" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n' > "$d/plan.md"
assert_exit_code 0 "completion-check.sh" "$d" BATON_BYPASS=1

echo "--- Test 14: Blocking message mentions Retrospective ---"
d="$tmp/cc6" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && sh "$BATON/completion-check.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "Retrospective" "blocking message mentions Retrospective"

# ============================================================
echo ""
echo "=== pre-compact.sh ==="

echo "--- Test 15: Implement phase → outputs progress ---"
d="$tmp/pc1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [ ] Step 2\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && sh "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "IMPLEMENT" "shows IMPLEMENT phase"
assert_output_contains "$OUTPUT" "1/2" "shows progress"

echo "--- Test 16: Annotation phase → outputs phase info ---"
d="$tmp/pc2" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
OUTPUT="$(cd "$d" && sh "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "PLAN/ANNOTATION" "shows PLAN/ANNOTATION phase"

echo "--- Test 17: No plan → silent ---"
d="$tmp/pc3" && mkdir -p "$d"
OUTPUT="$(cd "$d" && sh "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "Baton context" "no plan → silent"

echo "--- Test 18: Plan with Annotation Log → mentions it ---"
d="$tmp/pc4" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n## Annotation Log\nRound 1\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && sh "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "Annotation Log" "mentions Annotation Log exists"

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
