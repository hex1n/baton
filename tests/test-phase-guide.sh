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
assert_output_contains "$d" "Spike" "RESEARCH phase mentions spike/exploratory coding"
assert_exit_zero "$d" "always exit 0 (no files)"

# ============================================================
echo ""
echo "=== Test 2: research.md exists, no plan.md → PLAN phase guidance ==="
d="$tmp/t2" && mkdir -p "$d"
echo "# Research findings" > "$d/research.md"
assert_output_contains "$d" "PLAN" "outputs PLAN phase label"
assert_output_contains "$d" "research" "mentions research reference"
assert_output_contains "$d" "Todo list" "mentions not writing Todo list"
assert_output_contains "$d" "approach" "mentions approach analysis"
assert_output_contains "$d" "Mindset" "PLAN phase shows Mindset reminder"
assert_output_contains "$d" "constraints" "PLAN phase mentions constraints"
assert_output_contains "$d" "批注区" "PLAN phase mentions 批注区"
assert_exit_zero "$d" "always exit 0 (research, no plan)"

# ============================================================
echo ""
echo "=== Test 3: plan.md without GO → ANNOTATION phase guidance ==="
d="$tmp/t3" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
assert_output_contains "$d" "ANNOTATION" "outputs ANNOTATION cycle label"
assert_output_contains "$d" "\[PAUSE\]" "mentions PAUSE annotation"
assert_output_contains "$d" "Free-text is the default" "mentions free-text default"
assert_output_not_contains "$d" "\[NOTE\]" "does not mention NOTE annotation"
assert_output_not_contains "$d" "\[Q\]" "does not mention Q annotation"
assert_output_not_contains "$d" "\[CHANGE\]" "does not mention CHANGE annotation"
assert_output_contains "$d" "file:line" "mentions evidence-based response"
assert_output_contains "$d" "BATON:GO" "mentions BATON:GO unlock"
assert_output_contains "$d" "Mindset" "ANNOTATION phase shows Mindset reminder"
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
assert_output_contains "$d" "BATON:GO" "mentions BATON:GO"
assert_output_contains "$d" "Mindset" "IMPLEMENT phase shows Mindset reminder"
assert_output_contains "$d" "3x" "IMPLEMENT phase mentions 3x-stop rule"
assert_exit_zero "$d" "always exit 0 (implement)"

# ============================================================
echo ""
echo "=== Test 5: plan.md + GO + all todos done → FINISH phase ==="
d="$tmp/t5" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [x] Step 2: Done
- [x] Step 3: Done
EOF
assert_output_contains "$d" "FINISH phase" "detects FINISH phase"
assert_output_contains "$d" "Retrospective" "mentions Retrospective"
assert_output_contains "$d" "test suite" "mentions full test suite"
assert_output_contains "$d" "branch disposition" "mentions branch disposition"
assert_output_contains "$d" "BATON:COMPLETE" "mentions COMPLETE marker"
assert_output_contains "$d" "Mindset" "FINISH phase shows Mindset reminder"
assert_exit_zero "$d" "always exit 0 (finish)"

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
# Default → no plan found → RESEARCH (check before creating any plan file)
assert_output_contains "$d" "RESEARCH" "default plan name → RESEARCH (no plan.md)"
# Now create custom plan file and test BATON_PLAN override
cat > "$d/plan-custom.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
# Custom plan → IMPLEMENT
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && BATON_PLAN=plan-custom.md bash "$GUIDE" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "IMPLEMENT"; then
    echo "  pass: BATON_PLAN=plan-custom.md → IMPLEMENT guidance"
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
echo "=== Test 10: plan + GO + mixed todos → IMPLEMENT (not finish) ==="
d="$tmp/t10" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Step 1: Done
- [ ] Step 2: Not done
EOF
assert_output_contains "$d" "IMPLEMENT" "partial completion → IMPLEMENT phase"
assert_output_not_contains "$d" "All tasks complete" "partial completion → not finish"

# ============================================================
echo ""
echo "=== Test 11: plan + GO but no ## Todo → AWAITING_TODO ==="
d="$tmp/t11" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# My Plan
<!-- BATON:GO -->
Some content but no todo section
EOF
assert_output_contains "$d" "no actionable ## Todo" "GO without Todo → awaiting Todo list reminder"
assert_output_not_contains "$d" "IMPLEMENT phase" "GO without Todo → not IMPLEMENT"
assert_output_contains "$d" "generate Todo list" "reminds to generate Todo list"
assert_output_contains "$d" "Mindset" "AWAITING_TODO phase shows Mindset reminder"
assert_exit_zero "$d" "always exit 0 (awaiting todo)"

# ============================================================
echo ""
echo "=== Test 11b: plan + GO + ## Todo with trailing spaces → IMPLEMENT ==="
d="$tmp/t11b" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo   
- [ ] Step 1
EOF
assert_output_contains "$d" "IMPLEMENT" "trailing spaces in ## Todo still count as Todo section"
assert_output_not_contains "$d" "no actionable ## Todo" "trailing spaces do not regress to AWAITING_TODO"

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
echo "=== Test 18: find_plan() walk-up discovers plan-*.md from subdirectory ==="
d="$tmp/t18" && mkdir -p "$d/src/deep"
cat > "$d/plan-feature.md" << 'EOF'
# Plan for feature
Some content without BATON:GO
EOF
# cd to subdirectory, run phase-guide — should find plan-feature.md and show ANNOTATION (not RESEARCH)
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d/src/deep" && bash "$GUIDE" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "ANNOTATION"; then
    echo "  pass: walk-up finds plan-feature.md from subdirectory → ANNOTATION"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected ANNOTATION from walk-up plan-feature.md discovery"
    echo "  OUTPUT: $OUTPUT"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if ! echo "$OUTPUT" | grep -q "RESEARCH"; then
    echo "  pass: walk-up does not fall back to RESEARCH"
    PASS=$((PASS + 1))
else
    echo "  FAIL: walk-up fell back to RESEARCH (plan-feature.md not found)"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 19: Research fallback — single topic-named research file ==="
d="$tmp/t19" && mkdir -p "$d"
cat > "$d/research-hooks.md" << 'EOF'
# Research
## Final Conclusions
Hooks need hardening.
EOF
# No plan, no plan-hooks.md — should discover research-hooks.md via fallback
assert_output_contains "$d" "PLAN" "fallback research-hooks.md → PLAN phase"
assert_output_contains "$d" "baton-tasks" "mentions baton-tasks convention"
assert_output_not_contains "$d" "RESEARCH phase" "does NOT show RESEARCH phase label"

# ============================================================
echo ""
echo "=== Test 20: Research fallback — multiple research files ==="
d="$tmp/t20" && mkdir -p "$d"
echo "# R1" > "$d/research-hooks.md"
echo "# R2" > "$d/research-auth.md"
assert_output_contains "$d" "Multiple research files" "multi-research advisory warning"
assert_output_contains "$d" "PLAN" "multi-research → PLAN guidance (not RESEARCH)"
assert_output_not_contains "$d" "RESEARCH phase" "multi-research does NOT fall into RESEARCH state"

# ============================================================
echo ""
echo "=== Test 21: Final Conclusions gate — no FC ==="
d="$tmp/t21" && mkdir -p "$d"
echo "# Just research, no conclusions" > "$d/research.md"
assert_output_contains "$d" "no ## Final Conclusions" "warns about missing Final Conclusions"

echo "=== Test 21b: Final Conclusions gate — exactly 1 FC (no warning) ==="
d="$tmp/t21b" && mkdir -p "$d"
cat > "$d/research.md" << 'EOF'
# Research
## Final Conclusions
Good conclusions here.
EOF
assert_output_not_contains "$d" "Final Conclusions" "exactly 1 FC → no warning"

echo "=== Test 21c: Final Conclusions gate — multiple FC ==="
d="$tmp/t21c" && mkdir -p "$d"
cat > "$d/research.md" << 'EOF'
# Research
## Final Conclusions
First draft.
## Final Conclusions
Second draft.
EOF
assert_output_contains "$d" "multiple.*Final Conclusions" "warns about multiple FC sections"

# ============================================================
echo ""
echo "=== Test 22: ANNOTATION 批注区 detection ==="
d="$tmp/t22" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
## 批注区
This is human feedback that needs processing.
EOF
assert_output_contains "$d" "Unprocessed content" "detects unprocessed 批注区 content"

echo "=== Test 22b: ANNOTATION 批注区 — empty (no warning) ==="
d="$tmp/t22b" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
## 批注区
<!-- comments only -->
EOF
assert_output_not_contains "$d" "Unprocessed content" "empty 批注区 → no warning"

# ============================================================
echo ""
echo "=== Test 22c: ANNOTATION complexity hint — >3 files without Surface Scan ==="
d="$tmp/t22c" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
**Files**: `a.ts`, `b.ts`, `c.ts`, `d.ts`
EOF
assert_output_contains "$d" "Surface Scan" "complex plan without Surface Scan shows upgrade hint"

echo "=== Test 22d: ANNOTATION complexity hint suppressed when Surface Scan exists ==="
d="$tmp/t22d" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
## Surface Scan
| File | Level | Disposition | Reason |
|------|-------|-------------|--------|
| a.ts | L1 | modify | test |
**Files**: `a.ts`, `b.ts`, `c.ts`, `d.ts`
EOF
assert_output_not_contains "$d" "Surface Scan" "existing Surface Scan suppresses upgrade hint"

# ============================================================
echo ""
echo "=== Test 23: IMPLEMENT self-check output ==="
d="$tmp/t23" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] Step 1
EOF
assert_output_contains "$d" "Self-check" "IMPLEMENT shows self-check reminder"
assert_output_contains "$d" "re-read" "self-check mentions re-read"
assert_output_contains "$d" "consumers" "self-check mentions checking consumers"

# ============================================================
echo ""
echo "=== Test 24: FINISH conditional research — no research file ==="
d="$tmp/t24" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Done
EOF
TOTAL=$((TOTAL + 1))
OUTPUT="$(run_guide "$d")"
if echo "$OUTPUT" | grep -q 'mv .*research'; then
    echo "  FAIL: no research file → should not suggest mv research"
    FAIL=$((FAIL + 1))
else
    echo "  pass: no research file → no research mv suggestion"
    PASS=$((PASS + 1))
fi

echo "=== Test 24b: FINISH conditional research — with research file ==="
d="$tmp/t24b" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] Done
EOF
echo "# Research" > "$d/research.md"
assert_output_contains "$d" "BATON:COMPLETE" "with research file → FINISH mentions COMPLETE marker"

# ============================================================
echo ""
echo "=== Test 25: Multi-plan advisory warning ==="
d="$tmp/t25" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
echo "# Feature plan" > "$d/plan-feature.md"
assert_output_contains "$d" "Multiple plan files" "multi-plan advisory warning"

echo "=== Test 25b: Multi-plan + BATON_PLAN → no multi-plan warning ==="
d="$tmp/t25b" && mkdir -p "$d"
echo "# Plan" > "$d/plan.md"
echo "# Feature plan" > "$d/plan-feature.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && BATON_PLAN=plan.md bash "$GUIDE" 2>&1 1>/dev/null)"
if echo "$OUTPUT" | grep -q "Multiple plan files"; then
    echo "  FAIL: BATON_PLAN set → should not warn about multiple plans"
    FAIL=$((FAIL + 1))
else
    echo "  pass: BATON_PLAN set → no multi-plan warning"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 26: FINISH phase shows inline completion instructions ==="
d="$tmp/t26" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [x] ✅ 1. done
EOF
assert_output_contains "$d" "FINISH phase" "FINISH shows inline completion instructions"
assert_output_contains "$d" "Retrospective" "FINISH mentions retrospective"
assert_output_not_contains "$d" "/baton-finish" "FINISH does not reference /baton-finish"

# ============================================================
echo ""
echo "=== Test 27: IMPLEMENT with baton-debug skill → /baton-debug prompt ==="
d="$tmp/t27" && mkdir -p "$d/.claude/skills/baton-debug" "$d/.claude/skills/baton-implement"
cat > "$d/.claude/skills/baton-debug/SKILL.md" << 'EOF'
---
name: baton-debug
---
EOF
cat > "$d/.claude/skills/baton-implement/SKILL.md" << 'EOF'
---
name: baton-implement
---
EOF
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] 1. pending
EOF
assert_output_contains "$d" "/baton-debug" "IMPLEMENT with baton-debug skill shows /baton-debug"

# ============================================================
echo ""
echo "=== Test 27b: IMPLEMENT without baton-debug skill → no /baton-debug ==="
d="$tmp/t27b" && mkdir -p "$d/.claude/skills/baton-implement"
cat > "$d/.claude/skills/baton-implement/SKILL.md" << 'EOF'
---
name: baton-implement
---
EOF
cat > "$d/plan.md" << 'EOF'
<!-- BATON:GO -->
## Todo
- [ ] 1. pending
EOF
assert_output_not_contains "$d" "/baton-debug" "IMPLEMENT without baton-debug skill hides /baton-debug"

# ============================================================
echo ""
echo "=== Test 28: Section-aware counting — items outside ## Todo ignored ==="
d="$tmp/t28" && mkdir -p "$d"
cat > "$d/plan.md" << 'EOF'
# Plan
<!-- BATON:GO -->
## Approach
- [ ] Not a real todo
## Todo
- [x] ✅ Real item 1
- [x] ✅ Real item 2
## Notes
- [ ] Also not a todo
EOF
assert_output_contains "$d" "FINISH phase" "section-aware: only ## Todo items counted"

# ============================================================
echo ""
echo "=== Test: Governance context JSON output (stdout) ==="
# 5a: Basic governance context output — run_guide_stdout captures stdout (not stderr)
run_guide_stdout() {
    local dir="$1"
    (cd "$dir" && bash "$GUIDE" 2>/dev/null)
}

d="$tmp/tgov" && mkdir -p "$d"
TOTAL=$((TOTAL + 1))
GOV_OUT="$(run_guide_stdout "$d")"
if [ -n "$GOV_OUT" ]; then
    echo "  pass: governance context stdout is non-empty"
    PASS=$((PASS + 1))
else
    echo "  FAIL: governance context stdout should be non-empty (SKILL.md exists)"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$GOV_OUT" | grep -q 'additional_context\|additionalContext'; then
    echo "  pass: stdout contains additional_context\|additionalContext"
    PASS=$((PASS + 1))
else
    echo "  FAIL: stdout should contain additional_context\|additionalContext"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$GOV_OUT" | grep -q '{' && echo "$GOV_OUT" | grep -q '}'; then
    echo "  pass: stdout looks like JSON (has braces)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: stdout should contain JSON braces"
    FAIL=$((FAIL + 1))
fi

# 5b: Large content regression test — heredoc hang bug would timeout here
echo ""
echo "=== Test: Large SKILL.md content does not hang (heredoc regression) ==="
SKILL_PATH="$(cd "$(dirname "$GUIDE")" && pwd)/../skills/using-baton/SKILL.md"
if [ -f "$SKILL_PATH" ]; then
    SKILL_BACKUP="$(cat "$SKILL_PATH")"
    # Generate >2KB synthetic content
    python3 -c "print('x' * 3000)" > "$SKILL_PATH" 2>/dev/null || \
        printf '%0.sx' $(seq 1 3000) > "$SKILL_PATH"
    TOTAL=$((TOTAL + 1))
    LARGE_OUT=""
    # Run with timeout — heredoc bug would hang indefinitely
    if LARGE_OUT="$(timeout 10 bash -c "cd '$d' && bash '$GUIDE' 2>/dev/null")" 2>/dev/null || \
       LARGE_OUT="$(cd "$d" && bash "$GUIDE" 2>/dev/null)"; then
        if echo "$LARGE_OUT" | grep -q 'additional_context\|additionalContext'; then
            echo "  pass: large SKILL.md content outputs valid JSON without hang"
            PASS=$((PASS + 1))
        else
            echo "  FAIL: large SKILL.md should still produce additional_context\|additionalContext"
            FAIL=$((FAIL + 1))
        fi
    else
        echo "  FAIL: phase-guide.sh timed out with large SKILL.md (heredoc hang?)"
        FAIL=$((FAIL + 1))
    fi
    # Restore original SKILL.md
    printf '%s' "$SKILL_BACKUP" > "$SKILL_PATH"
else
    echo "  skip: SKILL.md not found at $SKILL_PATH"
fi

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
