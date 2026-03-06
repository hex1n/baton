#!/bin/sh
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 4.0
# Hook: SessionStart
# Dynamic extraction: reads phase-specific sections from workflow-full.md
# Fallback: hardcoded summaries if workflow-full.md is unavailable
# States: RESEARCH → PLAN → ANNOTATION → AWAITING_TODO → IMPLEMENT → ARCHIVE

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON phase-guide: unexpected error, skipping guidance" >&2; exit 0' HUP INT TERM

# --- Locate workflow-full.md ---
SCRIPT_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)"
WORKFLOW_FULL="${SCRIPT_DIR:+$SCRIPT_DIR/../workflow-full.md}"

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
    echo "📍 IMPLEMENT phase — <!-- BATON:GO --> is set" >&2
    echo "" >&2
    if extract_section "IMPLEMENT" "" >&2; then
        exit 0
    fi
    # Fallback
    cat >&2 <<'EOF'
For each todo item, follow this sequence:
1. Re-read the plan section for this item — understand WHAT and WHY
2. Read the target files before modifying — understand current state
3. Implement the change
4. Run typecheck/build. If it fails, fix before moving on
5. Mark [x] only AFTER verification passes

Quality checks:
- Only modify files listed in the plan. Need a new file? Stop, update plan, wait for confirmation
- Discover something the plan didn't anticipate? STOP. Update the plan, wait for human confirmation
- Same approach fails 3 times? Stop and report — don't keep trying

After ALL items complete: run full test suite, record results at bottom of the plan.
EOF
    exit 0
fi

# State 4: ANNOTATION — plan exists, no GO
if [ -n "$PLAN" ]; then
    echo "$MINDSET_LINE" >&2
    echo "📍 ANNOTATION cycle — $PLAN_NAME awaiting approval" >&2
    echo "" >&2
    if extract_section "ANNOTATION" "IMPLEMENT" >&2; then
        exit 0
    fi
    # Fallback
    cat >&2 <<EOF
Read the document carefully. Look for new annotations:
[NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]

For EACH annotation, BEFORE responding:
- [Q]: Don't answer from memory. Go read the actual code, then answer with file:line.
- [CHANGE]: Verify the change is safe first. Check callers, check tests, check edge cases.
  If you find a problem, say so with evidence — don't comply just because the human asked.
- [DEEPER]: Your previous work was insufficient. This is a signal to investigate seriously,
  not just add a paragraph.
- [RESEARCH-GAP]: Pause other annotations. Do the research. Append findings to the research document
  as ## Supplement. Then return.

Record every response in ## Annotation Log with:
- The annotation type and section
- Your response with file:line evidence
- The outcome (accepted / rejected / awaiting human decision)

The human is not always right. Your job is to surface what you know.
Blind compliance is a failure mode. So is hiding concerns.
When satisfied, human adds <!-- BATON:GO --> to approve the plan.
After approval, human says "generate todolist" to create implementation checklist.
Implementation begins only after todolist is generated.
EOF
    exit 0
fi

# State 5: PLAN — research exists, no plan
if [ -n "$RESEARCH" ]; then
    echo "$MINDSET_LINE" >&2
    echo "📍 PLAN phase — name the plan to match research: if research is $RESEARCH_NAME, produce ${PLAN_NAME}." >&2
    echo "   Use plan.md only for simple/generic tasks." >&2
    echo "" >&2
    if extract_section "PLAN" "ANNOTATION" >&2; then
        exit 0
    fi
    # Fallback
    cat >&2 <<EOF
Don't jump to "how to do it". Derive your approach from research findings:
1. Extract hard constraints from $RESEARCH_NAME (architecture limits, dependencies,
   backward compatibility, performance, team conventions)
2. Derive 2-3 approaches. For each:
   - Feasibility: ✅ feasible / ⚠️ risky / ❌ not feasible (with file:line evidence)
   - Pros and cons (analyzed against each constraint)
   - Impact scope (files touched, callers affected)
3. Recommend one + reasoning that traces back to specific research findings

If research revealed fundamental design problems:
- Present honestly: "file:line shows X, which means Y"
- Offer both: patch within existing structure vs. fix root problem
- State clearly: this is an architectural decision the human must make

Todolist is required — generate only after human says "generate todolist".
The plan must end with a ## 批注区 section for human annotations.

Before completing the plan, append ## Self-Review: biggest risk, what could make this wrong, one rejected alternative.
Calibrate depth to task complexity: trivial (1 file) → brief plan; complex → full analysis.
EOF
    exit 0
fi

# State 6: RESEARCH — nothing exists
echo "$MINDSET_LINE" >&2
echo "📍 RESEARCH phase — name the file by topic: research-<topic>.md (e.g., research-hooks.md)." >&2
echo "   Use research.md only for simple/generic tasks." >&2
echo "" >&2
if extract_section "RESEARCH" "PLAN" >&2; then
    exit 0
fi
# Fallback
cat >&2 <<EOF
You are investigating code you have never seen. Your goal: build understanding
deep enough that the human can judge whether you truly comprehend the system.

Execution strategy:
1. Identify entry points relevant to the task (human's request or affected files)
2. For each function/method call, read the IMPLEMENTATION — not just the interface
3. When a call delegates to another layer, follow it. Stop only at:
   framework internals, stdlib, or external deps (annotate WHY you stopped)
4. Use subagents to trace parallel branches when you find 3+ call paths (10+ files)

For every conclusion in $RESEARCH_NAME:
- Attach file:line evidence. No evidence = mark as ❓ unverified
- "Should be fine" is NOT a valid conclusion — verify or mark ❓
- Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified

When stopping at external deps/framework internals:
- Use available documentation retrieval tools to check authoritative docs
- Prefer official docs over assumptions about API behavior

The research document must end with a ## 批注区 section for human annotations.
Simple changes may skip research and go straight to $PLAN_NAME.

Before completing $RESEARCH_NAME, append ## Self-Review: 3 critical questions, weakest conclusion, what would change if investigated further.
Calibrate depth to task complexity: trivial changes → skip research; complex changes → full call chain tracing.
Exploratory code (spikes) → use Bash tool; record findings in $RESEARCH_NAME.
EOF

exit 0