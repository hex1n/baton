#!/bin/bash
# test-phase-guide.sh — Tests for phase-guide.sh v4.0 (SessionStart hook, dynamic extraction)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GUIDE="$SCRIPT_DIR/../.baton/hooks/phase-guide.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

run_guide() {
    # Run phase-guide.sh from given directory, capture stderr (guidance output)
    local dir="$1"
    (cd "$dir" && bash "$GUIDE" 2>&1 1>/dev/null)
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
        echo "    got: $output"
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
    if (cd "$dir" && bash "$GUIDE" 2>/dev/null); then
        echo "  pass: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc (expected exit 0)"
        FAIL=$((FAIL + 1))
    fi
}

# ============================================================
echo "=== Test 1: No files → RESEARCH phase guidance ==="
d="$tmp/t1" && mkdir -p "$d"
assert_output_contains "$d" "RESEARCH" "outputs RESEARCH phase label"
assert_output_contains "$d" "research.md" "mentions research.md"
assert_output_contains "$d" "implementations" "mentions reading implementations"
assert_output_contains "$d" "file:line" "mentions file:line evidence"
assert_output_contains "$d" "entry points" "mentions starting from entry points"
assert_output_contains "$d" "Mindset" "RESEARCH phase shows Mindset reminder"
assert_output_contains "$d" "subagent" "RESEARCH phase mentions subagents"
assert_output_contains "$d" "批注区" "RESEARCH phase mentions 批注区"
assert_output_contains "$d" "documentation retrieval" "RESEARCH phase mentions doc retrieval tools"
assert_output_contains "$d" "Self-Review" "RESEARCH phase mentions self-review"
assert_output_contains "$d" "Spike" "RESEARCH phase mentions spike/exploratory coding"
assert_exit_zero "$d" "always exit 0 (no files)"

# ============================================================
echo ""
echo "=== Test 2: research.md exists, no plan.md → PLAN phase guidance ==="
d="$tmp/t2" && mkdir -p "$d"
echo "# Research findings" > "$d/research.md"
assert_output_contains "$d" "PLAN" "outputs PLAN phase label"
assert_output_contains "$d" "research" "mentions research reference"
assert_output_contains "$d" "todolist" "mentions not writing todolist"
assert_output_contains "$d" "approach" "mentions approach analysis"
assert_output_contains "$d" "Mindset" "PLAN phase shows Mindset reminder"
assert_output_contains "$d" "constraints" "PLAN phase mentions constraints"
assert_output_contains "$d" "批注区" "PLAN phase mentions 批注区"
assert_output_contains "$d" "Self-Review" "PLAN phase mentions self-review"
assert_output_contains "$d" "Approach Analysis" "PLAN phase mentions approach analysis method"
assert_exit_zero "$d" "always exit 0 (research, no plan)"

# ============================================================
echo ""
echo "=== Test 3: plan.md without GO → ANNOTATION phase guidance ==="
d="$tmp/t3" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_output_contains "$d" "ANNOTATION" "outputs ANNOTATION cycle label"
assert_output_contains "$d" "\[PAUSE\]" "mentions PAUSE annotation"
assert_output_contains "$d" "Free-text is the default" "mentions free-text default"
assert_output_contains "$d" "Consequence detection" "mentions consequence detection"
assert_output_not_contains "$d" "\[NOTE\]" "does not mention NOTE annotation"
assert_output_not_contains "$d" "\[Q\]" "does not mention Q annotation"
assert_output_not_contains "$d" "\[CHANGE\]" "does not mention CHANGE annotation"
assert_output_contains "$d" "file:line" "mentions evidence-based response"
assert_output_contains "$d" "BATON:GO" "mentions BATON:GO unlock"
assert_output_contains "$d" "Mindset" "ANNOTATION phase shows Mindset reminder"
assert_output_contains "$d" "blind compliance" "ANNOTATION phase mentions blind compliance"
assert_exit_zero "$d" "always exit 0 (plan, no GO)"

# ============================================================
echo ""
echo "=== Test 4: plan.md with GO → IMPLEMENT phase guidance ==="
d="$tmp/t4" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
assert_output_contains "$d" "IMPLEMENT" "outputs IMPLEMENT phase label"
assert_output_contains "$d" "typecheck" "mentions typecheck"
assert_output_contains "$d" "BATON:GO" "mentions BATON:GO"
assert_output_contains "$d" "Mindset" "IMPLEMENT phase shows Mindset reminder"
assert_output_contains "$d" "re-read the modified code" "IMPLEMENT phase mentions re-reading code"
assert_output_contains "$d" "3x" "IMPLEMENT phase mentions 3x-stop rule"
assert_exit_zero "$d" "always exit 0 (implement)"

# ============================================================
echo ""
echo "=== Test 5: plan.md + GO + all todos done → ARCHIVE reminder ==="
d="$tmp/t5" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [x] Step 2: Done
- [x] Step 3: Done
EOF
assert_output_contains "$d" "All tasks complete" "detects all tasks completed"
assert_output_contains "$d" "archiving" "suggests archiving"
assert_output_contains "$d" "plans/" "mentions plans/ directory"
assert_output_contains "$d" "Annotation Log" "mentions Annotation Log value"
assert_output_contains "$d" "Mindset" "ARCHIVE phase shows Mindset reminder"
assert_exit_zero "$d" "always exit 0 (archive)"

# ============================================================
echo ""
echo "=== Test 6: No research.md + plan.md → ANNOTATION (simple change) ==="
d="$tmp/t6" && mkdir -p "$d"
echo "# Simple change plan" > "$d/plan.md"
# No research.md — plan was created directly (simple change scenario)
assert_output_contains "$d" "ANNOTATION" "annotation cycle for direct plan"
assert_exit_zero "$d" "always exit 0"

# ============================================================
echo ""
echo "=== Test 7: BATON_PLAN custom plan file name ==="
d="$tmp/t7" && mkdir -p "$d"
cat > "$d/custom.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
# Default → no plan found → RESEARCH
assert_output_contains "$d" "RESEARCH" "default plan name → RESEARCH (no plan.md)"
# Custom plan → IMPLEMENT
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && BATON_PLAN=custom.md bash "$GUIDE" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "IMPLEMENT"; then
    echo "  pass: BATON_PLAN=custom.md → IMPLEMENT guidance"
    PASS=$((PASS + 1))
else
    echo "  FAIL: BATON_PLAN should use custom plan file"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 8: Walk-up plan discovery ==="
d="$tmp/t8" && mkdir -p "$d/project/src/components"
echo "# Plan" > "$d/project/plan.md"
assert_output_contains "$d/project/src/components" "ANNOTATION" "walk-up finds plan.md in parent"

# ============================================================
echo ""
echo "=== Test 9: Phase guidance mutually exclusive ==="
d="$tmp/t9" && mkdir -p "$d"
# RESEARCH phase should not mention IMPLEMENT or ANNOTATION keywords
assert_output_not_contains "$d" "IMPLEMENT phase" "RESEARCH phase does not mention IMPLEMENT phase"
assert_output_not_contains "$d" "ANNOTATION" "RESEARCH phase does not mention ANNOTATION"

# ============================================================
echo ""
echo "=== Test 10: plan + GO + mixed todos → IMPLEMENT (not archive) ==="
d="$tmp/t10" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
assert_output_contains "$d" "IMPLEMENT" "partial completion → IMPLEMENT phase"
assert_output_not_contains "$d" "All tasks complete" "partial completion → not archive"

# ============================================================
echo ""
echo "=== Test 11: plan + GO but no ## Todo → AWAITING_TODO ==="
d="$tmp/t11" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# My Plan
<!-- BATON:GO -->
Some content but no todo section
EOF
assert_output_contains "$d" "no ## Todo found" "GO without Todo → awaiting todolist reminder"
assert_output_not_contains "$d" "IMPLEMENT phase" "GO without Todo → not IMPLEMENT"
assert_output_contains "$d" "generate todolist" "reminds to generate todolist"
assert_output_contains "$d" "Mindset" "AWAITING_TODO phase shows Mindset reminder"
assert_exit_zero "$d" "always exit 0 (awaiting todo)"

# ============================================================
echo ""
echo "=== Test 12: RESEARCH with baton-research skill → skill invocation prompt ==="
d="$tmp/t12" && mkdir -p "$d/.claude/skills/baton-research"
echo "---" > "$d/.claude/skills/baton-research/SKILL.md"
echo "name: baton-research" >> "$d/.claude/skills/baton-research/SKILL.md"
echo "---" >> "$d/.claude/skills/baton-research/SKILL.md"
assert_output_contains "$d" "/baton-research" "skill prompt shows /baton-research"
assert_output_contains "$d" "invoke" "skill prompt says invoke"
assert_output_not_contains "$d" "entry points" "fallback text suppressed when skill available"
assert_output_not_contains "$d" "subagent" "fallback guidance not shown when skill available"

# ============================================================
echo ""
echo "=== Test 13: PLAN with baton-plan skill → skill invocation prompt ==="
d="$tmp/t13" && mkdir -p "$d/.claude/skills/baton-plan"
echo "---" > "$d/.claude/skills/baton-plan/SKILL.md"
echo "name: baton-plan" >> "$d/.claude/skills/baton-plan/SKILL.md"
echo "---" >> "$d/.claude/skills/baton-plan/SKILL.md"
echo "# Research findings" > "$d/research.md"
assert_output_contains "$d" "/baton-plan" "skill prompt shows /baton-plan"
assert_output_contains "$d" "invoke" "skill prompt says invoke"
assert_output_not_contains "$d" "constraints" "fallback PLAN text suppressed when skill available"

# ============================================================
echo ""
echo "=== Test 14: ANNOTATION with baton-plan skill → skill invocation prompt ==="
d="$tmp/t14" && mkdir -p "$d/.claude/skills/baton-plan"
echo "---" > "$d/.claude/skills/baton-plan/SKILL.md"
echo "name: baton-plan" >> "$d/.claude/skills/baton-plan/SKILL.md"
echo "---" >> "$d/.claude/skills/baton-plan/SKILL.md"
echo "# Plan" > "$d/plan.md"
assert_output_contains "$d" "ANNOTATION" "shows ANNOTATION label"
assert_output_contains "$d" "/baton-plan" "skill prompt shows /baton-plan for annotation"
assert_output_not_contains "$d" "\[NOTE\]" "fallback ANNOTATION text suppressed when skill available"

# ============================================================
echo ""
echo "=== Test 15: IMPLEMENT with baton-implement skill → skill invocation prompt ==="
d="$tmp/t15" && mkdir -p "$d/.claude/skills/baton-implement"
echo "---" > "$d/.claude/skills/baton-implement/SKILL.md"
echo "name: baton-implement" >> "$d/.claude/skills/baton-implement/SKILL.md"
echo "---" >> "$d/.claude/skills/baton-implement/SKILL.md"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
assert_output_contains "$d" "/baton-implement" "skill prompt shows /baton-implement"
assert_output_not_contains "$d" "typecheck" "fallback IMPLEMENT text suppressed when skill available"

# ============================================================
echo ""
echo "=== Test 16: Skill walk-up detection from subdirectory ==="
d="$tmp/t16" && mkdir -p "$d/.claude/skills/baton-research" "$d/src/deep"
echo "---" > "$d/.claude/skills/baton-research/SKILL.md"
echo "name: baton-research" >> "$d/.claude/skills/baton-research/SKILL.md"
echo "---" >> "$d/.claude/skills/baton-research/SKILL.md"
# Run from subdirectory — skill should be found by walking up
assert_output_contains "$d/src/deep" "/baton-research" "walk-up finds skill from subdirectory"

# ============================================================
echo ""
echo "=== Test 17: Per-skill detection — only matching skill detected ==="
d="$tmp/t17" && mkdir -p "$d/.claude/skills/baton-research"
echo "---" > "$d/.claude/skills/baton-research/SKILL.md"
echo "name: baton-research" >> "$d/.claude/skills/baton-research/SKILL.md"
echo "---" >> "$d/.claude/skills/baton-research/SKILL.md"
echo "# Research findings" > "$d/research.md"
# In PLAN phase, baton-plan skill is NOT installed, so fallback should appear
assert_output_not_contains "$d" "/baton-plan" "baton-research doesn't trigger /baton-plan"
assert_output_contains "$d" "PLAN" "still shows PLAN phase"

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
