#!/bin/sh
# test-constitution-consistency.sh — Verify constitution.md content and cross-skill consistency
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/constitution.md"
README_FILE="$SCRIPT_DIR/../README.md"
SETUP="$SCRIPT_DIR/../setup.sh"
FIRST_PRINCIPLES="$SCRIPT_DIR/../docs/first-principles.md"
IMPL_DESIGN="$SCRIPT_DIR/../docs/implementation-design.md"
FAIL=0

# --- Core concepts: constitution.md must contain key baton concepts ---
echo "Checking core concepts in constitution.md..."
for concept in "No claim without evidence" "No silent agreement" "No guessing past uncertainty" \
               "No execution beyond authorization" "No stale authorization" "No completion by implication" \
               "BATON:GO" "file:line" "Authority Model" "Discovery protocol"; do
    if grep -q "$concept" "$SLIM"; then
        echo "OK: core concept '$concept' in constitution.md"
    else
        echo "DRIFT: core concept '$concept' missing from constitution.md"
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

# --- Constitution section structure ---
echo ""
echo "Checking constitution.md section structure..."
for section in "Core Invariants" "Authority Model" "State Model" "Permission Model" \
               "Evidence Model" "Challenge Model" "Completion Model" "Document Semantics"; do
    if grep -q "$section" "$SLIM"; then
        echo "OK: section '$section' in constitution.md"
    else
        echo "DRIFT: section '$section' missing from constitution.md"
        FAIL=1
    fi
done

# --- Key permission concepts ---
echo ""
echo "Checking key permission concepts..."
for concept in "Failure boundary" "Discovery protocol" "Scope boundary" "implementation-local"; do
    if grep -q "$concept" "$SLIM"; then
        echo "OK: '$concept' in constitution.md"
    else
        echo "DRIFT: '$concept' missing from constitution.md"
        FAIL=1
    fi
done

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

if grep -q "Artifacts" "$PLAN_SKILL" && grep -q "Deps" "$PLAN_SKILL"; then
    echo "OK: baton-plan includes artifacts and deps in todo schema"
else
    echo "DRIFT: baton-plan missing artifacts/deps in todo schema"
    FAIL=1
fi

if grep -q "explicit file ownership" "$IMPL_SKILL" && grep -q "Overlapping files" "$IMPL_SKILL"; then
    echo "OK: baton-implement guards parallel execution with file ownership"
else
    echo "DRIFT: baton-implement missing parallel execution guardrail"
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
for f in "$RESEARCH_SKILL" "$GUIDE" \
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

# Todo completion format must exist in baton-plan
if grep -q '\- \[x\] ✅' "$PLAN_SKILL"; then
    echo "OK: Todo completion format - [x] ✅ in baton-plan"
else
    echo "DRIFT: Todo completion format - [x] ✅ missing from baton-plan"
    FAIL=1
fi

# Iron Law #4 must exist in baton-plan
if grep -q 'NO INTERNAL CONTRADICTIONS' "$PLAN_SKILL"; then
    echo "OK: Iron Law #4 (no contradictions) in baton-plan"
else
    echo "DRIFT: Iron Law #4 missing from baton-plan"
    FAIL=1
fi

# baton-plan must handle internal contradictions (Iron Law #4)
# Annotation Protocol was moved to baton-research; plan catches contradictions via Iron Law
if grep -q 'NO INTERNAL CONTRADICTIONS' "$PLAN_SKILL"; then
    echo "OK: baton-plan handles contradictions via Iron Law"
else
    echo "DRIFT: baton-plan missing contradiction handling"
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

# baton-plan must have Self-Challenge step
if grep -q 'Self-Challenge' "$PLAN_SKILL"; then
    echo "OK: baton-plan has Self-Challenge step"
else
    echo "DRIFT: baton-plan missing Self-Challenge step"
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
   && grep -q 'Run the required validation' "$IMPL_SKILL"; then
    echo "OK: baton-implement has grep-for-bug and validation self-checks"
else
    echo "DRIFT: baton-implement missing grep-for-bug or validation self-checks"
    FAIL=1
fi

# --- Protocol drift guards (prevent re-introduction of fixed wording) ---
echo ""
echo "Checking protocol drift guards..."

# constitution.md must NOT contain README.md
if grep -q 'README\.md' "$SLIM"; then
    echo "DRIFT: constitution.md contains 'README.md' — keep documentation references out of slim protocol"
    FAIL=1
else
    echo "OK: constitution.md does not reference README.md"
fi

# constitution.md MUST contain Document Semantics
if grep -q 'Document Semantics' "$SLIM"; then
    echo "OK: constitution.md contains Document Semantics"
else
    echo "DRIFT: constitution.md missing 'Document Semantics'"
    FAIL=1
fi

# constitution.md must NOT contain old research.md rule
if grep -q 'All analysis tasks produce research\.md' "$SLIM"; then
    echo "DRIFT: constitution.md contains old rule 'All analysis tasks produce research.md' — should be Medium/Large only"
    FAIL=1
else
    echo "OK: constitution.md uses correct research.md scoping"
fi

# constitution.md MUST contain "approved write set"
if grep -q 'approved write set' "$SLIM"; then
    echo "OK: constitution.md contains 'approved write set'"
else
    echo "DRIFT: constitution.md missing 'approved write set' — was changed to vague wording"
    FAIL=1
fi

# constitution.md MUST contain discovery protocol with Q1/Q2
if grep -q 'Question 1' "$SLIM" && grep -q 'Question 2' "$SLIM"; then
    echo "OK: constitution.md has discovery protocol with Q1/Q2"
else
    echo "DRIFT: constitution.md missing discovery protocol Q1/Q2"
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

# baton-plan defines the Todo schema format
if grep -q 'Todo List Format' "$BATON_SKILLS_DIR/baton-plan/SKILL.md" \
   && grep -q 'Verify:' "$BATON_SKILLS_DIR/baton-plan/SKILL.md"; then
    echo "OK: baton-plan defines Todo schema with Verify field"
else
    echo "DRIFT: baton-plan missing Todo schema definition"
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

# --- Phase skill listing in Authority Model ---
echo ""
echo "Checking Authority Model phase skill listing..."

# Authority Model must list all 4 phase skills
for skill in baton-research baton-plan baton-implement baton-review; do
    if grep -q "$skill" "$SLIM"; then
        echo "OK: Authority Model lists $skill"
    else
        echo "DRIFT: Authority Model missing $skill"
        FAIL=1
    fi
done

# baton-finish must NOT appear in constitution.md (merged into implement)
if grep -q 'baton-finish' "$SLIM"; then
    echo "DRIFT: constitution.md still references baton-finish"
    FAIL=1
else
    echo "OK: constitution.md has no baton-finish references"
fi

# Completion Model must exist and require human confirmation
if grep -q 'Completion Model' "$SLIM" && grep -q 'human confirms' "$SLIM"; then
    echo "OK: Completion Model requires human confirmation"
else
    echo "DRIFT: Completion Model missing or lacks human confirmation requirement"
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
