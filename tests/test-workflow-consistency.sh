#!/bin/sh
# test-workflow-consistency.sh — Verify shared sections between workflow.md and workflow-full.md
set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SLIM="$SCRIPT_DIR/../.baton/workflow.md"
FULL="$SCRIPT_DIR/../.baton/workflow-full.md"
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

# --- find_plan consistency: all 4 scripts must find plan.md the same way ---
echo ""
echo "Checking find_plan consistency across hook scripts..."

# Extract the plan-finding walk-up loop (identified by PLAN_NAME reference)
extract_walk_up() {
    # Find the while loop that references PLAN_NAME (the plan-finding loop)
    awk '/while true/{buf=""; cap=1} cap{buf=buf $0 "\n"} cap && /done/{if(buf ~ /PLAN_NAME/) print buf; cap=0}' "$1" \
        | sed 's/#.*//' | sed '/^$/d' | sed 's/^[[:space:]]*//'
}

WL="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/write-lock.sh")"
PG="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/phase-guide.sh")"
SG="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/stop-guard.sh")"
BG="$(extract_walk_up "$SCRIPT_DIR/../.baton/hooks/bash-guard.sh")"

# phase-guide and stop-guard should be identical (both inline, same structure)
if [ "$PG" != "$SG" ]; then
    echo "DRIFT: find_plan loop differs between phase-guide.sh and stop-guard.sh"
    FAIL=1
else
    echo "OK: find_plan loop consistent (phase-guide.sh = stop-guard.sh)"
fi

# All must contain the core algorithm elements
for script in write-lock.sh phase-guide.sh stop-guard.sh bash-guard.sh; do
    path="$SCRIPT_DIR/../.baton/hooks/$script"
    body="$(extract_walk_up "$path")"
    # Must have: while loop, file test, dirname, parent==dir termination
    missing=""
    echo "$body" | grep -q 'while true' || missing="$missing while-loop"
    echo "$body" | grep -q 'PLAN_NAME' || missing="$missing PLAN_NAME"
    echo "$body" | grep -q 'dirname' || missing="$missing dirname"
    if [ -n "$missing" ]; then
        echo "DRIFT: $script find_plan missing core elements:$missing"
        FAIL=1
    else
        echo "OK: $script find_plan has all core elements"
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

if [ "$FAIL" -eq 1 ]; then
    echo ""
    echo "FAILED: consistency check detected drift"
    exit 1
else
    echo ""
    echo "ALL CONSISTENT"
    exit 0
fi
