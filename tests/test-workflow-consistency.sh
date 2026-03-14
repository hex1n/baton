#!/bin/sh
# test-workflow-consistency.sh — Verify shared sections between workflow.md and workflow-full.md
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
README_FILE="$SCRIPT_DIR/../README.md"
SETUP="$SCRIPT_DIR/../setup.sh"
FIRST_PRINCIPLES="$SCRIPT_DIR/../docs/first-principles.md"
IMPL_DESIGN="$SCRIPT_DIR/../docs/implementation-design.md"
FAIL=0

# --- Core concepts: workflow.md must contain key baton concepts ---
echo "Checking core concepts in workflow.md..."
for concept in "Mindset" "Verify before you claim" "Disagree with evidence" "Stop when uncertain" \
               "Scenario A" "Scenario B" "BATON:GO" "file:line" "批注区" "Annotation"; do
    if grep -q "$concept" "$SLIM"; then
        echo "OK: core concept '$concept' in workflow.md"
    else
        echo "DRIFT: core concept '$concept' missing from workflow.md"
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
GUIDE="$SCRIPT_DIR/../.baton/hooks/phase-guide.sh"

# --- 批注区 rule consistency ---
echo ""
echo "Checking 批注区 rule consistency..."
if grep -q "批注区" "$SLIM"; then
    echo "OK: 批注区 mentioned in workflow.md"
else
    echo "DRIFT: 批注区 not mentioned in workflow.md"
    FAIL=1
fi

# --- Complexity Calibration consistency ---
echo ""
echo "Checking Complexity Calibration consistency..."
if grep -q "Complexity Calibration" "$SLIM"; then
    echo "OK: Complexity Calibration in workflow.md"
else
    echo "DRIFT: Complexity Calibration not in workflow.md"
    FAIL=1
fi
for level in "Trivial" "Small" "Medium" "Large"; do
    if grep -q "$level" "$SLIM"; then
        echo "OK: complexity level '$level' in workflow.md"
    else
        echo "DRIFT: complexity level '$level' missing from workflow.md"
        FAIL=1
    fi
done

# --- Anti-sycophancy line consistency ---
echo ""
echo "Checking anti-sycophancy line consistency..."
SYCO="accuracy, not comfort"
if grep -q "$SYCO" "$SLIM"; then
    echo "OK: anti-sycophancy line in workflow.md"
else
    echo "DRIFT: anti-sycophancy line not in workflow.md"
    FAIL=1
fi

# Canonical skill source: .baton/skills/ (new canonical), .claude/skills/ (legacy fallback)
if [ -d "$SCRIPT_DIR/../.baton/skills" ]; then
    SKILLS_DIR="$SCRIPT_DIR/../.baton/skills"
else
    SKILLS_DIR="$SCRIPT_DIR/../.claude/skills"
fi

# --- Retrospective keyword consistency ---
echo ""
echo "Checking Retrospective keyword consistency..."
STOP="$SCRIPT_DIR/../.baton/hooks/stop-guard.sh"
if grep -q "Retrospective" "$STOP"; then
    echo "OK: Retrospective in stop-guard.sh"
else
    echo "DRIFT: Retrospective missing from stop-guard.sh"
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

if grep -q "Artifacts" "$PLAN_SKILL" && grep -q "Schema ownership" "$PLAN_SKILL"; then
    echo "OK: baton-plan includes artifacts in todo schema"
else
    echo "DRIFT: baton-plan missing artifacts in todo schema"
    FAIL=1
fi

if grep -q "write sets do" "$IMPL_SKILL" && grep -q "explicit file ownership" "$IMPL_SKILL"; then
    echo "OK: baton-implement guards parallel execution with write-set ownership"
else
    echo "DRIFT: baton-implement missing parallel write-set guardrail"
    FAIL=1
fi

if grep -q "Unexpected Discoveries" "$IMPL_SKILL" && grep -q "Scope extension" "$IMPL_SKILL"; then
    echo "OK: baton-implement handles unexpected discoveries with A/B/C/D levels"
else
    echo "DRIFT: baton-implement missing unexpected discoveries handling"
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

# --- Per-skill content assertions for baton-review and baton-debug ---
echo ""
echo "Checking baton-review skill content..."
REVIEW_SKILL="$SKILLS_DIR/baton-review/SKILL.md"

if [ -f "$REVIEW_SKILL" ]; then
    for kw in "Iron Law" "context: fork" "First-principles review" "Observability"; do
        if grep -qi "$kw" "$REVIEW_SKILL"; then
            echo "OK: baton-review contains '$kw'"
        else
            echo "DRIFT: baton-review missing '$kw'"
            FAIL=1
        fi
    done
else
    echo "DRIFT: baton-review SKILL.md not found at $REVIEW_SKILL"
    FAIL=1
fi

# baton-finish should NOT exist (merged into implement)
if [ -f "$SKILLS_DIR/baton-finish/SKILL.md" ]; then
    echo "DRIFT: baton-finish still exists (should be merged into implement)"
    FAIL=1
else
    echo "OK: baton-finish removed (merged into implement)"
fi

echo ""
echo "Checking baton-debug skill content..."
DEBUG_SKILL="$SKILLS_DIR/baton-debug/SKILL.md"

if [ -f "$DEBUG_SKILL" ]; then
    for kw in "Iron Law" "When to Use" "Reproduce" "Hypothesis" "root cause"; do
        if grep -q "$kw" "$DEBUG_SKILL"; then
            echo "OK: baton-debug contains '$kw'"
        else
            echo "DRIFT: baton-debug missing '$kw'"
            FAIL=1
        fi
    done
else
    echo "DRIFT: baton-debug SKILL.md not found at $DEBUG_SKILL"
    FAIL=1
fi

echo ""
echo "Checking baton-subagent skill content..."
SUBAGENT_SKILL="$SKILLS_DIR/baton-subagent/SKILL.md"

if [ -f "$SUBAGENT_SKILL" ]; then
    for kw in "Iron Law" "ISOLATED CONTEXT" "OVERLAPPING WRITE" "Context Construction" "Dispatch" "Completion Review"; do
        if grep -q "$kw" "$SUBAGENT_SKILL"; then
            echo "OK: baton-subagent contains '$kw'"
        else
            echo "DRIFT: baton-subagent missing '$kw'"
            FAIL=1
        fi
    done
else
    echo "DRIFT: baton-subagent SKILL.md not found at $SUBAGENT_SKILL"
    FAIL=1
fi

# --- Direction γ: [PAUSE] as only explicit type ---
echo ""
echo "Checking Direction γ annotation system..."
GUIDE="$SCRIPT_DIR/../.baton/hooks/phase-guide.sh"

# [PAUSE] must be in all annotation-related files and current protocol/runtime sources
for f in "$RESEARCH_SKILL" "$SLIM" "$GUIDE" \
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

# setup.sh onboarding must mention research, plan, and chat as feedback channels
if grep -q 'research file, plan file, or chat' "$SETUP" \
   && ! grep -q 'Give feedback in plan.md or chat' "$SETUP"; then
    echo "OK: setup.sh onboarding keeps research in the annotation loop"
else
    echo "DRIFT: setup.sh onboarding narrows feedback channels"
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
fname="$(basename "$PLAN_SKILL")"
if grep -q '审阅完成后添加 <!-- BATON:GO -->' "$PLAN_SKILL"; then
    echo "DRIFT: $fname plan template still contains nested BATON:GO comment"
    FAIL=1
else
    echo "OK: $fname plan template avoids nested BATON:GO comment"
fi

# Todo completion format should be aligned across workflow and active skills
if grep -q '\- \[x\] ✅' "$PLAN_SKILL" \
   && grep -q '\- \[x\] ✅' "$SLIM"; then
    echo "OK: todo completion format aligned on - [x] ✅ (plan + workflow)"
else
    echo "DRIFT: todo completion format differs across workflow/plan skill"
    FAIL=1
fi

# Iron Law #4 must exist in baton-plan
if grep -q 'NO INTERNAL CONTRADICTIONS' "$PLAN_SKILL"; then
    echo "OK: Iron Law #4 (no contradictions) in baton-plan"
else
    echo "DRIFT: Iron Law #4 missing from baton-plan"
    FAIL=1
fi

# Annotation Protocol must exist in baton-plan (covers direction change and contradiction detection)
if grep -q 'Annotation Protocol' "$PLAN_SKILL" && grep -q 'direction change\|contradiction' "$PLAN_SKILL"; then
    echo "OK: Annotation Protocol with direction/contradiction handling in baton-plan"
else
    echo "DRIFT: baton-plan missing Annotation Protocol with direction/contradiction handling"
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

# --- setup.sh should treat .baton/skills as canonical and generate host copies ---
echo ""
echo "Checking canonical skill source model..."
if grep -q '\.baton/skills.*(new canonical)' "$SETUP" \
   && grep -q 'resolve_skill_source_dir' "$SETUP"; then
    echo "OK: setup.sh treats .baton/skills as canonical source with resolve_skill_source_dir"
else
    echo "DRIFT: setup.sh does not treat .baton/skills as canonical source"
    FAIL=1
fi

# Backward-compatibility fallback to .claude/skills must exist
if grep -q '\.claude/skills.*fallback\|legacy fallback' "$SETUP" \
   && grep -q 'BATON_DIR/\.claude/skills' "$SETUP"; then
    echo "OK: setup.sh has .claude/skills backward-compatibility fallback"
else
    echo "DRIFT: setup.sh missing .claude/skills backward-compatibility fallback"
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
if grep -q 'Surface Scan' "$PLAN_SKILL" && grep -q 'L1' "$PLAN_SKILL" \
   && grep -q 'L2' "$PLAN_SKILL" && grep -q 'L3' "$PLAN_SKILL"; then
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

# baton-implement must have essential self-checks
if grep -q 'Self-Checks' "$IMPL_SKILL" && grep -q 'Re-read code' "$IMPL_SKILL"; then
    echo "OK: baton-implement has essential self-checks"
else
    echo "DRIFT: baton-implement missing essential self-checks"
    FAIL=1
fi

# baton-implement must have grep-for-same-bug and run-tests self-checks
if grep -q 'Grep for same bug' "$IMPL_SKILL" \
   && grep -q 'Run tests before marking done' "$IMPL_SKILL"; then
    echo "OK: baton-implement has grep-for-bug and test-before-done self-checks"
else
    echo "DRIFT: baton-implement missing grep-for-bug or test-before-done self-checks"
    FAIL=1
fi

# --- Protocol drift guards (prevent re-introduction of fixed wording) ---
echo ""
echo "Checking protocol drift guards..."

# workflow.md must NOT contain README.md (was polluting slim workflow)
if grep -q 'README\.md' "$SLIM"; then
    echo "DRIFT: workflow.md contains 'README.md' — keep documentation references out of slim protocol"
    FAIL=1
else
    echo "OK: workflow.md does not reference README.md"
fi

# workflow.md MUST contain Document Authority (authority model moved here from workflow-full.md)
if grep -q 'Document Authority' "$SLIM"; then
    echo "OK: workflow.md contains Document Authority"
else
    echo "DRIFT: workflow.md missing 'Document Authority' — authority model should be in workflow.md"
    FAIL=1
fi

# workflow.md must NOT contain old research.md rule
if grep -q 'All analysis tasks produce research\.md' "$SLIM"; then
    echo "DRIFT: workflow.md contains old rule 'All analysis tasks produce research.md' — should be Medium/Large only"
    FAIL=1
else
    echo "OK: workflow.md uses correct research.md scoping"
fi

# workflow.md MUST contain "approved write set"
if grep -q 'approved write set' "$SLIM"; then
    echo "OK: workflow.md contains 'approved write set'"
else
    echo "DRIFT: workflow.md missing 'approved write set' — was changed to vague wording"
    FAIL=1
fi

# workflow.md omission rule MUST contain "C/D-level"
if grep -q 'C/D-level' "$SLIM"; then
    echo "OK: workflow.md omission rule scoped to C/D-level"
else
    echo "DRIFT: workflow.md omission rule missing 'C/D-level' scope"
    FAIL=1
fi

# --- Canonical .baton/skills/ directory structure ---
echo ""
echo "Checking .baton/skills/ directory structure..."
BATON_SKILLS_DIR="$SCRIPT_DIR/../.baton/skills"
for _skill in baton-plan baton-implement baton-review baton-research baton-debug baton-subagent; do
    if [ -f "$BATON_SKILLS_DIR/$_skill/SKILL.md" ]; then
        echo "OK: .baton/skills/$_skill/SKILL.md exists"
    else
        echo "DRIFT: .baton/skills/$_skill/SKILL.md missing"
        FAIL=1
    fi
done

# --- Canonical ownership assertions ---
echo ""
echo "Checking canonical ownership assumptions..."

# baton-plan is the owner of the todo schema
if grep -q 'Schema ownership' "$BATON_SKILLS_DIR/baton-plan/SKILL.md" \
   && grep -q 'baton-plan owns' "$BATON_SKILLS_DIR/baton-plan/SKILL.md"; then
    echo "OK: baton-plan declares schema ownership of todo schema"
else
    echo "DRIFT: baton-plan missing schema ownership declaration"
    FAIL=1
fi

# baton-debug is an implementation-time subflow, not a standalone phase
if grep -qi 'implementation-time' "$BATON_SKILLS_DIR/baton-debug/SKILL.md" \
   && grep -q 'not a standalone phase' "$BATON_SKILLS_DIR/baton-debug/SKILL.md"; then
    echo "OK: baton-debug framed as implementation-time, not a standalone phase"
else
    echo "DRIFT: baton-debug missing implementation-time / not-a-standalone-phase framing"
    FAIL=1
fi

# baton-subagent is an optional implementation extension owned by baton-implement
if grep -q 'optional implementation extension' "$BATON_SKILLS_DIR/baton-subagent/SKILL.md" \
   && grep -q 'owned by baton-implement' "$BATON_SKILLS_DIR/baton-subagent/SKILL.md"; then
    echo "OK: baton-subagent framed as optional implementation extension owned by baton-implement"
else
    echo "DRIFT: baton-subagent missing optional-implementation-extension / owned-by-baton-implement framing"
    FAIL=1
fi

# --- FINISH phase promotion assertions ---
echo ""
echo "Checking FINISH phase promotion in workflow.md..."

# Flow scenarios must end in 'completion'
if grep -q 'implement → completion' "$SLIM"; then
    echo "OK: Flow scenarios end in '→ completion'"
else
    echo "DRIFT: Flow scenarios do not end in '→ completion'"
    FAIL=1
fi

# Rule 10 must include baton-review in skill list (not baton-finish)
if grep '10\.' "$SLIM" | grep -q 'baton-review'; then
    echo "OK: Rule 10 includes baton-review in skill invocation list"
else
    echo "DRIFT: Rule 10 missing baton-review in skill invocation list"
    FAIL=1
fi

# baton-finish must NOT appear in workflow.md (merged into implement)
if grep -q 'baton-finish' "$SLIM"; then
    echo "DRIFT: workflow.md still references baton-finish"
    FAIL=1
else
    echo "OK: workflow.md has no baton-finish references"
fi

# Document Authority must list baton-review as core phase skill
if grep -qi 'Core phase skills.*baton-review' "$SLIM"; then
    echo "OK: Document Authority lists baton-review as core phase skill"
else
    echo "DRIFT: Document Authority missing baton-review as core phase skill"
    FAIL=1
fi

# workflow.md must have first-principles in Mindset
if grep -q 'First principles before framing' "$SLIM"; then
    echo "OK: workflow.md Mindset includes first-principles"
else
    echo "DRIFT: workflow.md Mindset missing first-principles"
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
