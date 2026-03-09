#!/bin/sh
# test-workflow-consistency.sh — Verify shared sections between workflow.md and workflow-full.md
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
FULL="$SCRIPT_DIR/../.baton/workflow-full.md"
README_FILE="$SCRIPT_DIR/../README.md"
SETUP="$SCRIPT_DIR/../setup.sh"
FIRST_PRINCIPLES="$SCRIPT_DIR/../docs/first-principles.md"
IMPL_DESIGN="$SCRIPT_DIR/../docs/implementation-design.md"
FAIL=0

extract_section() {
    awk -v sect="### $2" 'BEGIN{f=0} $0==sect{f=1} f && /^---$/{exit} f && /^### / && $0!=sect{exit} f{print}' "$1"
}

for section in "Mindset" "Action Boundaries" "File Conventions" "Session Handoff"; do
    A="$(extract_section "$SLIM" "$section")"
    B="$(extract_section "$FULL" "$section")"
    if [ -z "$A" ] && [ -z "$B" ]; then
        echo "DRIFT: '$section' not found in either file (false positive guard)"
        FAIL=1
    elif [ "$A" != "$B" ]; then
        echo "DRIFT: '$section' differs between workflow.md and workflow-full.md"
        FAIL=1
    else
        echo "OK: '$section' is consistent"
    fi
done

# --- Shared core concepts: workflow.md must contain key concepts from workflow-full.md ---
echo ""
echo "Checking shared core concepts..."
for concept in "Mindset" "Verify before you claim" "Disagree with evidence" "Stop when uncertain" \
               "Scenario A" "Scenario B" "BATON:GO" "file:line" "批注区" "Annotation"; do
    if grep -q "$concept" "$SLIM" && grep -q "$concept" "$FULL"; then
        echo "OK: core concept '$concept' in both files"
    else
        echo "DRIFT: core concept '$concept' not in both workflow files"
        FAIL=1
    fi
done

# --- _common.sh: shared functions must exist and be sourced by all hooks ---
echo ""
echo "Checking _common.sh shared library..."
COMMON="$SCRIPT_DIR/../.baton/hooks/_common.sh"

# _common.sh must define the shared functions
for func in resolve_plan_name find_plan has_skill; do
    if grep -q "^${func}()" "$COMMON"; then
        echo "OK: _common.sh defines $func"
    else
        echo "DRIFT: _common.sh missing function $func"
        FAIL=1
    fi
done

# All hooks must source _common.sh
for script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh \
              post-write-tracker.sh completion-check.sh pre-compact.sh subagent-context.sh; do
    path="$SCRIPT_DIR/../.baton/hooks/$script"
    if grep -q '_common\.sh' "$path"; then
        echo "OK: $script sources _common.sh"
    else
        echo "DRIFT: $script does not source _common.sh"
        FAIL=1
    fi
done

# No hook should still have SYNCED comments (duplication eliminated)
echo ""
echo "Checking no residual SYNCED comments..."
for script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh \
              post-write-tracker.sh completion-check.sh pre-compact.sh subagent-context.sh; do
    path="$SCRIPT_DIR/../.baton/hooks/$script"
    if grep -q 'SYNCED:' "$path"; then
        echo "DRIFT: $script still has SYNCED comment"
        FAIL=1
    else
        echo "OK: $script no SYNCED comments"
    fi
done
# --- Flow line consistency: Scenario A and B must match ---
echo ""
echo "Checking Flow line consistency..."
GUIDE="$SCRIPT_DIR/../.baton/hooks/phase-guide.sh"

for scenario in "Scenario A" "Scenario B"; do
    LINE_SLIM="$(grep -m1 "$scenario" "$SLIM" 2>/dev/null || true)"
    LINE_FULL="$(grep -m1 "$scenario" "$FULL" 2>/dev/null || true)"
    if [ -z "$LINE_SLIM" ] && [ -z "$LINE_FULL" ]; then
        echo "WARN: '$scenario' not found in either file"
    elif [ "$LINE_SLIM" != "$LINE_FULL" ]; then
        echo "DRIFT: '$scenario' line differs between workflow.md and workflow-full.md"
        FAIL=1
    else
        echo "OK: '$scenario' line is consistent"
    fi
done

# --- phase-guide.sh keyword cross-validation ---
echo ""
echo "Checking phase-guide.sh keywords in workflow-full.md..."

# RESEARCH phase keywords
for kw in "RESEARCH" "file:line" "subagent" "批注区"; do
    if grep -q "$kw" "$GUIDE" && ! grep -q "$kw" "$FULL"; then
        echo "DRIFT: phase-guide.sh mentions '$kw' but workflow-full.md does not"
        FAIL=1
    else
        echo "OK: keyword '$kw' consistent"
    fi
done

# IMPLEMENT phase keywords
for kw in "typecheck" "BATON:GO" "3x"; do
    if grep -q "$kw" "$GUIDE" && ! grep -q "$kw" "$FULL"; then
        echo "DRIFT: phase-guide.sh mentions '$kw' but workflow-full.md does not"
        FAIL=1
    else
        echo "OK: keyword '$kw' consistent"
    fi
done

# --- 批注区 rule consistency ---
echo ""
echo "Checking 批注区 rule consistency..."
if grep -q "批注区" "$SLIM" && grep -q "批注区" "$FULL"; then
    echo "OK: 批注区 mentioned in both workflow files"
else
    echo "DRIFT: 批注区 not consistently mentioned in both workflow files"
    FAIL=1
fi

# --- Complexity Calibration consistency ---
echo ""
echo "Checking Complexity Calibration consistency..."
if grep -q "Complexity Calibration" "$SLIM" && grep -q "Complexity Calibration" "$FULL"; then
    echo "OK: Complexity Calibration in both workflow files"
else
    echo "DRIFT: Complexity Calibration not consistently present"
    FAIL=1
fi
for level in "Trivial" "Small" "Medium" "Large"; do
    if grep -q "$level" "$SLIM" && grep -q "$level" "$FULL"; then
        echo "OK: complexity level '$level' in both files"
    else
        echo "DRIFT: complexity level '$level' not consistently present"
        FAIL=1
    fi
done

# --- Anti-sycophancy line consistency ---
echo ""
echo "Checking anti-sycophancy line consistency..."
SYCO="accuracy, not comfort"
if grep -q "$SYCO" "$SLIM" && grep -q "$SYCO" "$FULL"; then
    echo "OK: anti-sycophancy line in both workflow files"
else
    echo "DRIFT: anti-sycophancy line not consistently present"
    FAIL=1
fi

# --- Self-Review keyword consistency (SKILL.md or phase-guide ↔ workflow-full) ---
echo ""
echo "Checking Self-Review keyword consistency..."
SKILLS_DIR="$SCRIPT_DIR/../.claude/skills"
SKILL_HAS_SELF_REVIEW=false
for _skill_dir in "$SKILLS_DIR"/baton-*/; do
    [ -f "$_skill_dir/SKILL.md" ] && grep -q "Self-Review" "$_skill_dir/SKILL.md" && SKILL_HAS_SELF_REVIEW=true
done
if ($SKILL_HAS_SELF_REVIEW || grep -q "Self-Review" "$GUIDE") && grep -q "Self-Review" "$FULL"; then
    echo "OK: Self-Review in skills/phase-guide and workflow-full.md"
else
    echo "DRIFT: Self-Review not consistent between skills/phase-guide and workflow-full.md"
    FAIL=1
fi

# --- Retrospective keyword consistency ---
echo ""
echo "Checking Retrospective keyword consistency..."
STOP="$SCRIPT_DIR/../.baton/hooks/stop-guard.sh"
if grep -q "Retrospective" "$FULL" && grep -q "Retrospective" "$STOP"; then
    echo "OK: Retrospective in both workflow-full.md and stop-guard.sh"
else
    echo "DRIFT: Retrospective not consistent between workflow-full.md and stop-guard.sh"
    FAIL=1
fi

# --- SKILL.md frontmatter validation ---
echo ""
echo "Checking SKILL.md frontmatter..."
for _skill_dir in "$SKILLS_DIR"/baton-*/; do
    [ -d "$_skill_dir" ] || continue
    _skill_file="$_skill_dir/SKILL.md"
    [ -f "$_skill_file" ] || { echo "DRIFT: $_skill_dir missing SKILL.md"; FAIL=1; continue; }
    _dir_name="$(basename "$_skill_dir")"
    # name must match directory name
    _skill_name="$(awk '/^---$/{n++} n==1 && /^name:/{sub(/^name:[[:space:]]*/, ""); print; exit}' "$_skill_file")"
    if [ "$_skill_name" = "$_dir_name" ]; then
        echo "OK: $_dir_name name matches directory"
    else
        echo "DRIFT: $_dir_name name='$_skill_name' does not match directory"
        FAIL=1
    fi
    # description must exist and be non-empty
    if sed -n '/^---$/,/^---$/p' "$_skill_file" | grep -q 'description:'; then
        echo "OK: $_dir_name has description"
    else
        echo "DRIFT: $_dir_name missing description"
        FAIL=1
    fi
    # description must be under 1024 characters
    _desc_len="$(awk '/^---$/{n++} n==1 && /^description:/{found=1; sub(/^description:[[:space:]]*>?[[:space:]]*/, ""); print} n==1 && found && /^  /{print} /^[a-z]/ && found && !/^  /{found=0}' "$_skill_file" | tr -d '\n' | wc -c | tr -d ' ')"
    if [ "$_desc_len" -lt 1024 ]; then
        echo "OK: $_dir_name description length ${_desc_len} < 1024"
    else
        echo "DRIFT: $_dir_name description too long (${_desc_len} chars)"
        FAIL=1
    fi
done

# --- SKILL.md covers key baton concepts ---
echo ""
echo "Checking SKILL.md covers key baton concepts..."
for concept in "file:line" "BATON:GO" "批注区" "Iron Law"; do
    _found_in=""
    for _skill_dir in "$SKILLS_DIR"/baton-*/; do
        [ -f "$_skill_dir/SKILL.md" ] && grep -q "$concept" "$_skill_dir/SKILL.md" && _found_in="$_found_in $(basename "$_skill_dir")"
    done
    if [ -n "$_found_in" ]; then
        echo "OK: '$concept' found in:$_found_in"
    else
        echo "DRIFT: '$concept' not found in any SKILL.md"
        FAIL=1
    fi
done

# --- Skill-specific guardrails introduced after retrospective reviews ---
echo ""
echo "Checking skill guardrails for derived artifacts and parallel execution..."
PLAN_SKILL="$SKILLS_DIR/baton-plan/SKILL.md"
IMPL_SKILL="$SKILLS_DIR/baton-implement/SKILL.md"

if grep -q "Derived artifacts" "$PLAN_SKILL" && grep -q "NOT implicitly exempt" "$PLAN_SKILL"; then
    echo "OK: baton-plan requires explicit derived artifact listing"
else
    echo "DRIFT: baton-plan missing derived artifact planning guardrail"
    FAIL=1
fi

if grep -q "write sets do" "$IMPL_SKILL" && grep -q "explicit file ownership" "$IMPL_SKILL"; then
    echo "OK: baton-implement guards parallel execution with write-set ownership"
else
    echo "DRIFT: baton-implement missing parallel write-set guardrail"
    FAIL=1
fi

if grep -q "Derived artifact changed" "$IMPL_SKILL" && grep -q "No global exemption" "$IMPL_SKILL"; then
    echo "OK: baton-implement treats derived artifacts as explicit, not implicit"
else
    echo "DRIFT: baton-implement missing derived artifact execution guardrail"
    FAIL=1
fi

RESEARCH_SKILL="$SKILLS_DIR/baton-research/SKILL.md"

if grep -q "Counterexample Sweep" "$RESEARCH_SKILL" && grep -q "disprove" "$RESEARCH_SKILL"; then
    echo "OK: baton-research requires counterexample sweep before conclusions"
else
    echo "DRIFT: baton-research missing counterexample sweep guardrail"
    FAIL=1
fi

if grep -q "Exit Criteria" "$RESEARCH_SKILL" && grep -q "Main path verified" "$RESEARCH_SKILL"; then
    echo "OK: baton-research has explicit exit criteria"
else
    echo "DRIFT: baton-research missing exit criteria"
    FAIL=1
fi

# --- Direction γ: [PAUSE] as only explicit type ---
echo ""
echo "Checking Direction γ annotation system..."
GUIDE="$SCRIPT_DIR/../.baton/hooks/phase-guide.sh"

# [PAUSE] must be in all annotation-related files and current protocol/runtime sources
for f in "$PLAN_SKILL" "$RESEARCH_SKILL" "$SLIM" "$FULL" "$GUIDE" \
         "$README_FILE" "$SETUP" "$FIRST_PRINCIPLES" "$IMPL_DESIGN"; do
    fname="$(basename "$f")"
    if grep -q '\[PAUSE\]' "$f"; then
        echo "OK: [PAUSE] found in $fname"
    else
        echo "DRIFT: [PAUSE] not found in $fname"
        FAIL=1
    fi
done

# Current skills/docs must not retain legacy explicit marker terminology
for f in "$PLAN_SKILL" "$RESEARCH_SKILL" "$README_FILE" "$SETUP" \
         "$FIRST_PRINCIPLES" "$IMPL_DESIGN"; do
    case "$f" in
        "$PLAN_SKILL"|"$RESEARCH_SKILL") fname="$(basename "$(dirname "$f")")/$(basename "$f")" ;;
        *) fname="$(basename "$f")" ;;
    esac
    legacy_found=0
    for marker in '\[NOTE\]' '\[Q\]' '\[CHANGE\]' '\[DEEPER\]' '\[MISSING\]' '\[RESEARCH-GAP\]' '\[WRONG\]'; do
        if grep -q "$marker" "$f"; then
            echo "DRIFT: $fname still contains legacy explicit marker $marker"
            FAIL=1
            legacy_found=1
        fi
    done
    if [ "$legacy_found" -eq 0 ]; then
        echo "OK: $fname no longer contains legacy explicit marker terminology"
    fi
done

# phase-guide fallback must not mention the legacy 6-type list
if grep -q '\[NOTE\].*\[Q\].*\[CHANGE\].*\[DEEPER\].*\[MISSING\].*\[RESEARCH-GAP\]' "$GUIDE"; then
    echo "DRIFT: phase-guide.sh fallback still contains legacy annotation types"
    FAIL=1
else
    echo "OK: phase-guide.sh fallback uses Direction γ"
fi

# Current protocol docs must document the free-text + intent-inference model
for f in "$README_FILE" "$SETUP" "$FIRST_PRINCIPLES" "$IMPL_DESIGN"; do
    fname="$(basename "$f")"
    if grep -Eq 'Free-text is the default|自由文本' "$f" \
       && grep -Eq 'infers intent|推断意图' "$f"; then
        echo "OK: $fname documents free-text + intent inference"
    else
        echo "DRIFT: $fname missing free-text + intent inference guidance"
        FAIL=1
    fi
done

# setup.sh onboarding must point to research.md as well as plan.md
if grep -q 'research.md, plan.md, or chat' "$SETUP" \
   && ! grep -q 'Give feedback in plan.md or chat' "$SETUP"; then
    echo "OK: setup.sh onboarding keeps research.md in the annotation loop"
else
    echo "DRIFT: setup.sh onboarding narrows feedback to plan.md"
    FAIL=1
fi

# Old 6-type annotation list must NOT appear in 批注区 templates
# (They may still appear in general prose or historical references, but not in the template blocks)
for f in "$PLAN_SKILL" "$RESEARCH_SKILL"; do
    fname="$(basename "$(dirname "$f")")/$(basename "$f")"
    if grep -A3 '批注区' "$f" | grep -q '\[Q\].*\[CHANGE\]\|\[DEEPER\].*\[MISSING\]'; then
        echo "DRIFT: $fname 批注区 template still contains old type list"
        FAIL=1
    else
        echo "OK: $fname 批注区 template uses Direction γ"
    fi
done

# Template guidance must not use invalid nested HTML comments around BATON:GO
for f in "$PLAN_SKILL" "$FULL"; do
    fname="$(basename "$f")"
    if grep -q '审阅完成后添加 <!-- BATON:GO -->' "$f"; then
        echo "DRIFT: $fname plan template still contains nested BATON:GO comment"
        FAIL=1
    else
        echo "OK: $fname plan template avoids nested BATON:GO comment"
    fi
done

# Todo completion format should be aligned across workflow and active skills
if grep -q '\- \[x\] ✅' "$PLAN_SKILL" \
   && grep -q '\- \[x\] ✅' "$IMPL_SKILL" \
   && grep -q '\- \[x\] ✅' "$SLIM" \
   && grep -q '\- \[x\] ✅' "$FULL"; then
    echo "OK: todo completion format aligned on - [x] ✅"
else
    echo "DRIFT: todo completion format differs across workflow/skills"
    FAIL=1
fi

# Iron Law #4 must exist in baton-plan
if grep -q 'NO INTERNAL CONTRADICTIONS' "$PLAN_SKILL"; then
    echo "OK: Iron Law #4 (no contradictions) in baton-plan"
else
    echo "DRIFT: Iron Law #4 missing from baton-plan"
    FAIL=1
fi

# Consequence detection must exist in baton-plan
if grep -q 'Consequence detection' "$PLAN_SKILL"; then
    echo "OK: Consequence detection in baton-plan"
else
    echo "DRIFT: Consequence detection missing from baton-plan"
    FAIL=1
fi

# Convergence Check must exist in baton-research
if grep -q 'Convergence Check' "$RESEARCH_SKILL"; then
    echo "OK: Convergence Check in baton-research"
else
    echo "DRIFT: Convergence Check missing from baton-research"
    FAIL=1
fi

# Final Conclusions reference must exist in baton-research
if grep -q 'Final Conclusions' "$RESEARCH_SKILL"; then
    echo "OK: Final Conclusions in baton-research"
else
    echo "DRIFT: Final Conclusions missing from baton-research"
    FAIL=1
fi

# --- setup.sh should treat .claude/skills as canonical and generate .agents fallback ---
echo ""
echo "Checking Codex generated-surface model..."
if grep -q "canonical source in \\.claude/skills" "$SETUP" \
   && grep -q '\$BATON_DIR/\.claude/skills/\$_skill/SKILL\.md' "$SETUP"; then
    echo "OK: setup.sh treats .claude/skills as canonical source"
else
    echo "DRIFT: setup.sh no longer treats .claude/skills as canonical source"
    FAIL=1
fi

if grep -q '\$PROJECT_DIR/\.agents/skills/\$_skill/SKILL\.md' "$SETUP"; then
    echo "OK: setup.sh generates .agents/skills fallback for Codex"
else
    echo "DRIFT: setup.sh no longer generates .agents/skills fallback"
    FAIL=1
fi

# --- Surface Scan and cascading defense consistency ---
echo ""
echo "Checking Surface Scan and cascading defense consistency..."

# baton-plan must have Surface Scan step
if grep -q 'Surface Scan' "$PLAN_SKILL" && grep -q 'Level 1' "$PLAN_SKILL" \
   && grep -q 'Level 2' "$PLAN_SKILL" && grep -q 'Level 3' "$PLAN_SKILL"; then
    echo "OK: baton-plan has Surface Scan with L1/L2/L3"
else
    echo "DRIFT: baton-plan missing Surface Scan framework"
    FAIL=1
fi

# baton-plan Self-Review must reference disposition table
if grep -q 'disposition table' "$PLAN_SKILL"; then
    echo "OK: baton-plan Self-Review references disposition table"
else
    echo "DRIFT: baton-plan Self-Review missing disposition table completeness check"
    FAIL=1
fi

# baton-implement must have regression check in "After writing code" trigger
if grep -q 'Regression check' "$IMPL_SKILL" && grep -q 'surrounding context' "$IMPL_SKILL"; then
    echo "OK: baton-implement has regression check trigger"
else
    echo "DRIFT: baton-implement missing regression check trigger"
    FAIL=1
fi

# baton-implement must have cascading defense triggers
if grep -q 'After completing each todo' "$IMPL_SKILL" \
   && grep -q 'already changed by a prior todo' "$IMPL_SKILL" \
   && grep -q 'After modifying any file' "$IMPL_SKILL"; then
    echo "OK: baton-implement has cascading defense triggers"
else
    echo "DRIFT: baton-implement missing cascading defense triggers"
    FAIL=1
fi

# workflow-full.md must have Surface Scan hint
if grep -q 'Surface Scan' "$FULL" && grep -q 'disposition table' "$FULL"; then
    echo "OK: workflow-full.md has Surface Scan references"
else
    echo "DRIFT: workflow-full.md missing Surface Scan alignment"
    FAIL=1
fi

# workflow-full.md must have cascading triggers matching baton-implement
if grep -q 'After completing each todo' "$FULL" \
   && grep -q 'already changed by a prior todo' "$FULL"; then
    echo "OK: workflow-full.md has cascading triggers aligned with baton-implement"
else
    echo "DRIFT: workflow-full.md missing cascading triggers"
    FAIL=1
fi

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "FAILED: consistency check detected drift"
    exit 1
else
    echo ""
    echo "ALL CONSISTENT"
    exit 0
fi
