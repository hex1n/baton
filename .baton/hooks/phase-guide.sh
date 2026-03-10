#!/usr/bin/env bash
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 5.0
# Hook: SessionStart
# Skills-first: prompts skill invocation when baton skills are available
# Fallback: extracts from workflow-full.md or hardcoded summaries
# States: RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → ARCHIVE

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON phase-guide: unexpected error, skipping guidance" >&2; exit 0' HUP INT TERM

# --- Source shared functions ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
if [ -f "$SCRIPT_DIR/_common.sh" ]; then
    . "$SCRIPT_DIR/_common.sh"
else
    echo "⚠️ BATON phase-guide: _common.sh not found, skipping guidance" >&2
    exit 0
fi
WORKFLOW_FULL="${SCRIPT_DIR:+$SCRIPT_DIR/../workflow-full.md}"

MINDSET_LINE="⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain"

resolve_plan_name
RESEARCH_NAME="${PLAN_NAME/plan/research}"
find_plan

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
Read the document for feedback. Free-text is the default; [PAUSE] means stop and investigate first.
For each piece: infer intent, verify with file:line before responding, then answer with evidence.
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
