#!/bin/sh
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 5.0
# Hook: SessionStart
# Skills-first: prompts skill invocation when baton skills are available
# Fallback: extracts from workflow-full.md or hardcoded summaries
# States: RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → ARCHIVE

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON phase-guide: unexpected error, skipping guidance" >&2; exit 0' HUP INT TERM

# --- Locate workflow-full.md and skills ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
WORKFLOW_FULL="${SCRIPT_DIR:+$SCRIPT_DIR/../workflow-full.md}"

# Check if a specific baton skill is installed (walk up from cwd, like find_plan)
has_skill() {
    _hs_name="$1"
    _hs_d="$(pwd)"
    while true; do
        for _hs_ide in .claude .cursor .windsurf .cline .github .augment .roo .kiro .amazonq .agents; do
            [ -f "$_hs_d/$_hs_ide/skills/$_hs_name/SKILL.md" ] && return 0
        done
        _hs_p="$(dirname "$_hs_d")"
        [ "$_hs_p" = "$_hs_d" ] && return 1
        _hs_d="$_hs_p"
    done
    return 1
}

# extract_section SEC [NEXT_SEC]
# Extracts from ### [SEC] to ### [NEXT_SEC] (exclusive).
# If NEXT_SEC is empty, extracts to end of file.
# Returns 1 if extraction fails or is empty.
extract_section() {
    [ -z "$WORKFLOW_FULL" ] || [ ! -f "$WORKFLOW_FULL" ] && return 1
    _es_sec="$1"
    _es_next="${2:-}"
    if [ -n "$_es_next" ]; then
        _es_out="$(awk -v sec="$_es_sec" -v nxt="$_es_next" '
            $0 ~ "^### \\[" sec "\\]" {found=1}
            found && $0 ~ "^### \\[" nxt "\\]" {exit}
            found {print}
        ' "$WORKFLOW_FULL" 2>/dev/null)"
    else
        _es_out="$(awk -v sec="$_es_sec" '
            $0 ~ "^### \\[" sec "\\]" {found=1}
            found {print}
        ' "$WORKFLOW_FULL" 2>/dev/null)"
    fi
    [ -z "$_es_out" ] && return 1
    printf '%s\n' "$_es_out"
    return 0
}

MINDSET_LINE="⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain"

# SYNCED: plan-name-resolution — same in all baton scripts
if [ -n "$BATON_PLAN" ]; then
    PLAN_NAME="$BATON_PLAN"
else
    _candidate="$(ls -t plan.md plan-*.md 2>/dev/null | head -1)"
    PLAN_NAME="${_candidate:-plan.md}"
fi
RESEARCH_NAME="${PLAN_NAME/plan/research}"

# SYNCED: find_plan — same algorithm in write-lock.sh, stop-guard.sh, bash-guard.sh
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done

# Find research.md in same directory as plan (or cwd)
PLAN_DIR="${PLAN%/*}"
[ -z "$PLAN_DIR" ] && PLAN_DIR="$(pwd)"
RESEARCH=""
[ -f "$PLAN_DIR/$RESEARCH_NAME" ] && RESEARCH="$PLAN_DIR/$RESEARCH_NAME"

# --- State detection (priority high → low) ---

# State 1: ARCHIVE — all todos done
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    TOTAL=$(grep -c '^\- \[' "$PLAN" 2>/dev/null) || TOTAL=0
    DONE=$(grep -ci '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0
    if [ "$TOTAL" -gt 0 ] && [ "$TOTAL" -eq "$DONE" ]; then
        cat >&2 <<EOF
$MINDSET_LINE
📋 All tasks complete. Consider archiving:
   mkdir -p plans && mv $PLAN_NAME plans/plan-\$(date +%Y-%m-%d)-topic.md
   mv $RESEARCH_NAME plans/research-\$(date +%Y-%m-%d)-topic.md
💡 The Annotation Log records design decision rationale — valuable long-term reference.
EOF
        exit 0
    fi
fi

# State 2: AWAITING_TODO — plan + GO but no ## Todo
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    if ! grep -qi '^## Todo$' "$PLAN" 2>/dev/null; then
        cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📍 BATON:GO is set but no ## Todo found.
Ask the human to say "generate todolist" before starting implementation.
Implementation begins only after todolist is generated.
EOF
        exit 0
    fi
fi

# State 3: IMPLEMENT — plan + GO (+ Todo exists)
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    echo "$MINDSET_LINE" >&2
    if has_skill baton-implement; then
        echo "📍 IMPLEMENT phase — invoke /baton-implement for execution discipline" >&2
    else
        echo "📍 IMPLEMENT phase — <!-- BATON:GO --> is set" >&2
        echo "" >&2
        extract_section "IMPLEMENT" "" >&2 || cat >&2 <<'EOF'
For each todo item: re-read plan intent → implement → self-check → verify → mark [x].
Only modify files listed in the plan. Discover omission → STOP, update plan.
Same approach fails 3x → STOP and report.
EOF
    fi
    exit 0
fi

# State 4: ANNOTATION — plan exists, no GO
if [ -n "$PLAN" ]; then
    echo "$MINDSET_LINE" >&2
    echo "📍 ANNOTATION cycle — $PLAN_NAME awaiting approval" >&2
    if has_skill baton-plan; then
        echo "   Review annotations in the plan. Invoke /baton-plan for annotation protocol." >&2
    else
        echo "" >&2
        extract_section "ANNOTATION" "IMPLEMENT" >&2 || cat >&2 <<EOF
Read the document for annotations: [NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]
For each: verify with file:line before responding. Disagree with evidence when needed.
Record in ## Annotation Log. Human adds <!-- BATON:GO --> when satisfied.
EOF
    fi
    exit 0
fi

# State 5: PLAN — research exists, no plan
if [ -n "$RESEARCH" ]; then
    echo "$MINDSET_LINE" >&2
    if has_skill baton-plan; then
        echo "📍 PLAN phase — invoke /baton-plan to create change proposal from research" >&2
        echo "   Name the plan to match research: if research is $RESEARCH_NAME, produce ${PLAN_NAME}." >&2
    else
        echo "📍 PLAN phase — name the plan to match research: if research is $RESEARCH_NAME, produce ${PLAN_NAME}." >&2
        echo "   Use plan.md only for simple/generic tasks." >&2
        echo "" >&2
        extract_section "PLAN" "ANNOTATION" >&2 || cat >&2 <<EOF
Derive approaches from research findings. Don't jump to solutions.
Extract constraints → derive 2-3 approaches → recommend with reasoning.
Plan must end with ## 批注区. Todolist generated only after human says so.
EOF
    fi
    exit 0
fi

# State 6: RESEARCH — nothing exists
echo "$MINDSET_LINE" >&2
if has_skill baton-research; then
    echo "📍 RESEARCH phase — invoke /baton-research to begin investigation" >&2
    echo "   Name the file by topic: research-<topic>.md. Use research.md for simple tasks." >&2
else
    echo "📍 RESEARCH phase — name the file by topic: research-<topic>.md (e.g., research-hooks.md)." >&2
    echo "   Use research.md only for simple/generic tasks." >&2
    echo "" >&2
    extract_section "RESEARCH" "PLAN" >&2 || cat >&2 <<EOF
Investigate code: start from entry points, trace call chains with file:line evidence.
Read implementations, not just interfaces. Stop at framework internals (annotate why).
Use subagents for 3+ call paths. Spike with Bash. End with ## 批注区.
Simple changes may skip research and go straight to $PLAN_NAME.
EOF
fi

exit 0
