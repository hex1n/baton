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
    (cd "$dir" && "$@" bash "$BATON/$hook" 2>&1 1>/dev/null) || true
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
    (cd "$dir" && env "$@" bash "$BATON/$hook" </dev/null 2>/dev/null 1>/dev/null) || actual=$?
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
OUTPUT="$(cd "$d" && BATON_TARGET="src/app.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "file in plan → no warning"

echo "--- Test 2: File NOT in plan → warning ---"
d="$tmp/pwt2" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Update src/app.ts\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && BATON_TARGET="src/other.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "not mentioned" "file not in plan → warning"

echo "--- Test 3: Markdown file → no warning (always allowed) ---"
d="$tmp/pwt3" && mkdir -p "$d"
OUTPUT="$(cd "$d" && BATON_TARGET="research.md" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "markdown always passes silently"

echo "--- Test 4: No plan → silent exit ---"
d="$tmp/pwt4" && mkdir -p "$d"
OUTPUT="$(cd "$d" && BATON_TARGET="src/app.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "no plan → silent exit"

echo "--- Test 5: BATON_BYPASS=1 → silent exit ---"
d="$tmp/pwt5" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && BATON_BYPASS=1 BATON_TARGET="src/app.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not mentioned" "bypass → silent exit"

echo "--- Test 5b: GO + no Todo + unlisted file → still warns (skip-todolist path) ---"
d="$tmp/pwt6" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Approach\nModify src/app.ts\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && BATON_TARGET="src/other.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "not mentioned" "GO + no Todo + unlisted file → warning"

echo "--- Test 5c: Exact path matching — file in Files: field → no warning ---"
d="$tmp/pwt_exact1" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Update the app
  Files: `src/app.ts`, `src/utils.ts`
EOF
OUTPUT="$(cd "$d" && BATON_TARGET="src/app.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not in" "exact match: file in Files: → no warning"

echo "--- Test 5d: Exact path matching — file NOT in Files: field → warning with expected paths ---"
d="$tmp/pwt_exact2" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Update the app
  Files: `src/app.ts`, `src/utils.ts`
EOF
OUTPUT="$(cd "$d" && BATON_TARGET="src/other.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "not in" "exact match: file not in Files: → warning"
assert_output_contains "$OUTPUT" "Expected files" "exact match: warning shows expected files"
assert_output_contains "$OUTPUT" "src/app.ts" "exact match: warning lists expected path"

echo "--- Test 5e: Exact path matching — ./prefix normalization ---"
d="$tmp/pwt_exact3" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Update the app
  Files: `src/app.ts`
EOF
OUTPUT="$(cd "$d" && BATON_TARGET="./src/app.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not in" "exact match: ./prefix normalized → no warning"

echo "--- Test 5f: Exact path matching prefers Files: over basename ---"
d="$tmp/pwt_exact4" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Update src/app.ts
  Files: `src/app.ts`
EOF
OUTPUT="$(cd "$d" && BATON_TARGET="lib/app.ts" bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "not in" "exact: same basename different dir → warning (not just basename match)"

echo "--- Test 5g: Exact path matching — JSON cwd resolves relative paths ---"
d="$tmp/pwt_cwd" && mkdir -p "$d/src"
(cd "$d" && git init -q 2>/dev/null)
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Update main
  Files: `main.go`
EOF
JSON="{\"tool_input\":{\"file_path\":\"../main.go\"},\"cwd\":\"$d/src\"}"
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | bash "$BATON/post-write-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "not in" "cwd-aware: ../main.go from src/ resolves to main.go"

# ============================================================
echo ""
echo "=== subagent-context.sh ==="

echo "--- Test 6: Plan with todos → outputs context ---"
d="$tmp/sc1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [ ] Step 2\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && bash "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "1/2" "shows progress count"
assert_output_contains "$OUTPUT" "Step" "shows todo items"

echo "--- Test 7: No plan → silent ---"
d="$tmp/sc2" && mkdir -p "$d"
OUTPUT="$(cd "$d" && bash "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "Baton plan" "no plan → silent"

echo "--- Test 8: Plan without GO → silent ---"
d="$tmp/sc3" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
OUTPUT="$(cd "$d" && bash "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "Baton plan" "no GO → silent"

echo "--- Test 6b: Section-aware — only ## Todo items counted ---"
d="$tmp/sc_section" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Approach
- [ ] Not a real todo
## Todo
- [x] Step 1
- [ ] Step 2
## Notes
- [ ] Also not a todo
EOF
OUTPUT="$(cd "$d" && bash "$BATON/subagent-context.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "1/2" "section-aware: only counts ## Todo items"
assert_output_not_contains "$OUTPUT" "Not a real todo" "section-aware: excludes non-todo checklist items from output"
assert_output_not_contains "$OUTPUT" "Also not a todo" "section-aware: excludes later checklist items from output"

# ============================================================
echo ""
echo "=== completion-check.sh ==="

echo "--- Test 9: All done + no Retrospective → exit 2 (block) ---"
d="$tmp/cc1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [x] Step 2\n' > "$d/plan.md"
assert_exit_code 2 "completion-check.sh" "$d"

echo "--- Test 10: All done + has Retrospective (≥3 lines) → exit 0 (allow) ---"
d="$tmp/cc2" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1
## Retrospective
Plan was mostly right.
API surprised us with rate limits.
Would research dependencies more next time.
EOF
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

echo "--- Test 14: Blocking message mentions finish workflow and Retrospective ---"
d="$tmp/cc6" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && bash "$BATON/completion-check.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "FINISH phase" "blocking message mentions FINISH phase"
assert_output_contains "$OUTPUT" "Retrospective" "blocking message mentions Retrospective"
assert_output_contains "$OUTPUT" "finish workflow" "blocking message mentions finish workflow"

# ============================================================
echo ""
echo "=== Test 15: completion-check walk-up finds plan-*.md from subdirectory ==="
d="$tmp/t15" && mkdir -p "$d/src/deep"
cat > "$d/plan-feature.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] ✅ Step 1: done
EOF
# Run from subdirectory — should find plan-feature.md, all done, no Retrospective → exit 2
assert_exit_code 2 "completion-check.sh" "$d/src/deep"

echo "--- Test 10b: All done + Retrospective header only → exit 2 ---"
d="$tmp/cc2b" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1
## Retrospective
EOF
assert_exit_code 2 "completion-check.sh" "$d"

echo "--- Test 10c: All done + Retrospective 2 lines → exit 2 ---"
d="$tmp/cc2c" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1
## Retrospective
Plan was fine.
One surprise.
EOF
assert_exit_code 2 "completion-check.sh" "$d"

echo "--- Test 10d2: All done + Retrospective Notes → exit 2 (exact header required) ---"
d="$tmp/cc2d2" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1
## Retrospective Notes
Plan was fine.
One surprise.
Would research differently.
EOF
assert_exit_code 2 "completion-check.sh" "$d"

echo "--- Test 10d: Multi-plan + no BATON_PLAN → exit 2 ---"
d="$tmp/cc_mp" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1
## Retrospective
Plan was fine.
One surprise.
Would research differently.
EOF
echo "# Other" > "$d/plan-feature.md"
assert_exit_code 2 "completion-check.sh" "$d"

echo "--- Test 10e: Multi-plan + BATON_PLAN → exit 0 (retro OK) ---"
TOTAL=$((TOTAL + 1))
actual=0
(cd "$d" && env BATON_PLAN=plan.md bash "$BATON/completion-check.sh" </dev/null 2>/dev/null 1>/dev/null) || actual=$?
if [ "$actual" -eq 0 ]; then
    echo "  pass: exit code $actual == 0"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected exit 0, got $actual"
    FAIL=$((FAIL + 1))
fi

echo "--- Test 10f: Section-aware — items outside ## Todo not counted ---"
d="$tmp/cc_section" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Approach
- [ ] Not a real todo
## Todo
- [x] Step 1
## Retrospective
Plan was good.
Something surprised us.
Would do differently.
EOF
assert_exit_code 0 "completion-check.sh" "$d"

# ============================================================
echo ""
echo "=== pre-compact.sh ==="

echo "--- Test 16: Implement phase → outputs progress ---"
d="$tmp/pc1" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [ ] Step 2\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && bash "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "IMPLEMENT" "shows IMPLEMENT phase"
assert_output_contains "$OUTPUT" "1/2" "shows progress"

echo "--- Test 17: Annotation phase → outputs phase info ---"
d="$tmp/pc2" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
OUTPUT="$(cd "$d" && bash "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "PLAN/ANNOTATION" "shows PLAN/ANNOTATION phase"

echo "--- Test 18: No plan → silent ---"
d="$tmp/pc3" && mkdir -p "$d"
OUTPUT="$(cd "$d" && bash "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "Baton context" "no plan → silent"

echo "--- Test 19: Plan with Annotation Log → mentions it ---"
d="$tmp/pc4" && mkdir -p "$d"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n## Annotation Log\nRound 1\n' > "$d/plan.md"
OUTPUT="$(cd "$d" && bash "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "Annotation Log" "mentions Annotation Log exists"

echo "--- Test 16b: Section-aware — only ## Todo items counted ---"
d="$tmp/pc_section" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Approach
- [ ] Not a real todo
## Todo
- [x] Step 1
- [ ] Step 2
EOF
OUTPUT="$(cd "$d" && bash "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "1/2" "section-aware: only counts ## Todo items"
assert_output_not_contains "$OUTPUT" "Not a real todo" "pre-compact excludes non-todo checklist items"

echo "--- Test 16c: FINISH phase → outputs FINISH summary ---"
d="$tmp/pc_finish" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1
## Notes
- [ ] not a todo
EOF
OUTPUT="$(cd "$d" && bash "$BATON/pre-compact.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "FINISH" "pre-compact shows FINISH when all todos are complete"
assert_output_not_contains "$OUTPUT" "not a todo" "pre-compact FINISH summary excludes non-todo checklist items"

# ============================================================
echo ""
echo "=== failure-tracker.sh ==="

echo "--- Test 20: First failure → counter file created ---"
d="$tmp/ft1" && mkdir -p "$d"
SESSION_ID="test-$$-ft1"
# Clean up any prior runs
rm -f "/tmp/baton-failures-${SESSION_ID}"
OUTPUT="$(cd "$d" && echo '{"session_id":"'"$SESSION_ID"'","tool_name":"Edit"}' | bash "$BATON/failure-tracker.sh" 2>&1 1>/dev/null)" || true
TOTAL=$((TOTAL + 1))
if [ -f "/tmp/baton-failures-${SESSION_ID}" ]; then
    echo "  pass: counter file created"
    PASS=$((PASS + 1))
else
    echo "  FAIL: counter file should be created"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
COUNT=$(wc -l < "/tmp/baton-failures-${SESSION_ID}" | tr -d ' ')
if [ "$COUNT" -eq 1 ]; then
    echo "  pass: counter = 1 after first failure"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected count 1, got $COUNT"
    FAIL=$((FAIL + 1))
fi
assert_output_not_contains "$OUTPUT" "⚠️" "no warning on first failure"

echo "--- Test 21: Third failure → threshold alert ---"
# Add 2 more failures (total = 3)
echo '{"session_id":"'"$SESSION_ID"'","tool_name":"Write"}' | bash "$BATON/failure-tracker.sh" 2>/dev/null 1>/dev/null || true
OUTPUT="$(echo '{"session_id":"'"$SESSION_ID"'","tool_name":"Bash"}' | bash "$BATON/failure-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "3 tool failures" "3-failure threshold alert"

echo "--- Test 22: Fourth failure → no alert (only at exact thresholds) ---"
OUTPUT="$(echo '{"session_id":"'"$SESSION_ID"'","tool_name":"Edit"}' | bash "$BATON/failure-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_not_contains "$OUTPUT" "⚠️" "no alert at 4 failures"

echo "--- Test 23: Fifth failure → second threshold alert ---"
OUTPUT="$(echo '{"session_id":"'"$SESSION_ID"'","tool_name":"Edit"}' | bash "$BATON/failure-tracker.sh" 2>&1 1>/dev/null)" || true
assert_output_contains "$OUTPUT" "5 tool failures" "5-failure threshold alert"

echo "--- Test 24: PPID fallback when no session_id ---"
# When no session_id in JSON, failure-tracker uses PPID. Since we run in a subshell,
# PPID is the subshell's parent. Check that *some* counter file was created in /tmp.
BEFORE_FILES="$(ls /tmp/baton-failures-* 2>/dev/null | sort || true)"
echo '{}' | bash "$BATON/failure-tracker.sh" 2>/dev/null 1>/dev/null || true
AFTER_FILES="$(ls /tmp/baton-failures-* 2>/dev/null | sort || true)"
TOTAL=$((TOTAL + 1))
# Find the new file by diffing before/after
NEW_FILE="$(diff <(echo "$BEFORE_FILES") <(echo "$AFTER_FILES") 2>/dev/null | grep '^>' | head -1 | sed 's/^> //')" || true
if [ -n "$NEW_FILE" ] && [ -f "$NEW_FILE" ]; then
    echo "  pass: PPID fallback creates counter file ($NEW_FILE)"
    PASS=$((PASS + 1))
    rm -f "$NEW_FILE"
else
    echo "  FAIL: PPID fallback should create counter file"
    FAIL=$((FAIL + 1))
fi

echo "--- Test 24b: jq-less fallback parses camelCase session/tool fields ---"
SESSION_ID="test-$$-ft-camel"
rm -f "/tmp/baton-failures-${SESSION_ID}"
NOJQ_BIN="$tmp/nojq-bin"
mkdir -p "$NOJQ_BIN"
for cmd in awk cat date head tr wc; do
    CMD_PATH="$(command -v "$cmd" 2>/dev/null || true)"
    [ -n "$CMD_PATH" ] && ln -sf "$CMD_PATH" "$NOJQ_BIN/$cmd"
done
OUTPUT="$(cd "$d" && env PATH="$NOJQ_BIN" "$(command -v bash)" "$BATON/failure-tracker.sh" <<< '{"sessionId":"'"$SESSION_ID"'","toolName":"Write"}' 2>&1 1>/dev/null)" || true
TOTAL=$((TOTAL + 1))
if [ -f "/tmp/baton-failures-${SESSION_ID}" ] && grep -q '^Write ' "/tmp/baton-failures-${SESSION_ID}" 2>/dev/null; then
    echo "  pass: jq-less fallback uses camelCase sessionId/toolName"
    PASS=$((PASS + 1))
    rm -f "/tmp/baton-failures-${SESSION_ID}"
else
    echo "  FAIL: jq-less fallback should parse camelCase sessionId/toolName"
    echo "    output: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

echo "--- Test 25: Always exits 0 (advisory) ---"
TOTAL=$((TOTAL + 1))
EXIT_CODE=0
echo '{"session_id":"test-exit-check","tool_name":"Edit"}' | bash "$BATON/failure-tracker.sh" >/dev/null 2>&1 || EXIT_CODE=$?
if [ "$EXIT_CODE" -eq 0 ]; then
    echo "  pass: failure-tracker exits 0"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected exit 0, got $EXIT_CODE"
    FAIL=$((FAIL + 1))
fi

# Clean up temp files
rm -f "/tmp/baton-failures-${SESSION_ID}" "/tmp/baton-failures-test-exit-check"

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
