#!/bin/sh
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 3.1
# Hook: SessionStart
# NOTE: Guidance text intentionally duplicates workflow-full.md sections.
# When updating, sync both files. See tests/test-annotation-protocol.sh.
# States: RESEARCH → PLAN → ANNOTATION → IMPLEMENT → ARCHIVE

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON phase-guide: unexpected error, skipping guidance" >&2; exit 0' HUP INT TERM

PLAN_NAME="${BATON_PLAN:-plan.md}"
RESEARCH_NAME="research.md"

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
    DONE=$(grep -c '^\- \[x\]' "$PLAN" 2>/dev/null) || DONE=0
    if [ "$TOTAL" -gt 0 ] && [ "$TOTAL" -eq "$DONE" ]; then
        cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📋 All tasks complete. Consider archiving:
   mkdir -p plans && mv plan.md plans/plan-$(date +%Y-%m-%d)-topic.md
   mv research.md plans/research-$(date +%Y-%m-%d)-topic.md
💡 The Annotation Log records design decision rationale — valuable long-term reference.
EOF
        exit 0
    fi
fi

# State 2: IMPLEMENT — plan + GO
if [ -n "$PLAN" ] && grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📍 IMPLEMENT phase — <!-- BATON:GO --> is set

For each todo item, follow this sequence:
1. Re-read the plan section for this item — understand WHAT and WHY
2. Read the target files before modifying — understand current state
3. Implement the change
4. Run typecheck/build. If it fails, fix before moving on
5. Mark [x] only AFTER verification passes

Quality checks:
- Only modify files listed in the plan. Need a new file? Stop, update plan, wait for confirmation
- Discover something the plan didn't anticipate? STOP. Update plan.md, wait for human confirmation
- Same approach fails 3 times? Stop and report — don't keep trying

After ALL items complete: run full test suite, record results at bottom of plan.md.
Todo items with dependencies: execute sequentially. Independent items: may run in parallel.
EOF
    exit 0
fi

# State 3: ANNOTATION — plan exists, no GO
if [ -n "$PLAN" ]; then
    cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📍 ANNOTATION cycle — plan.md awaiting approval

Read the document carefully. Look for new annotations:
[NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]

For EACH annotation, BEFORE responding:
- [Q]: Don't answer from memory. Go read the actual code, then answer with file:line.
- [CHANGE]: Verify the change is safe first. Check callers, check tests, check edge cases.
  If you find a problem, say so with evidence — don't comply just because the human asked.
- [DEEPER]: Your previous work was insufficient. This is a signal to investigate seriously,
  not just add a paragraph.
- [RESEARCH-GAP]: Pause other annotations. Do the research. Append findings to research.md
  as ## Supplement. Then return.

Record every response in ## Annotation Log with:
- The annotation type and section
- Your response with file:line evidence
- The outcome (accepted / rejected / awaiting human decision)

The human is not always right. Your job is to surface what you know.
Blind compliance is a failure mode. So is hiding concerns.
Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
EOF
    exit 0
fi

# State 4: PLAN — research exists, no plan
if [ -n "$RESEARCH" ]; then
    cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📍 PLAN phase — produce plan.md (based on research.md + requirements)

Don't jump to "how to do it". Derive your approach from research findings:
1. Extract hard constraints from research.md (architecture limits, dependencies,
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

Do NOT write todolist — generate only after human says "generate todolist".
EOF
    exit 0
fi

# State 5: RESEARCH — nothing exists
cat >&2 << 'EOF'
⚠️ Mindset: verify before claiming · disagree with evidence · stop when uncertain
📍 RESEARCH phase — produce research.md

You are investigating code you have never seen. Your goal: build understanding
deep enough that the human can judge whether you truly comprehend the system.

Execution strategy:
1. Identify entry points relevant to the task (human's request or affected files)
2. For each function/method call, read the IMPLEMENTATION — not just the interface
3. When a call delegates to another layer, follow it. Stop only at:
   framework internals, stdlib, or external deps (annotate WHY you stopped)
4. Use subagents to trace parallel branches when you find 3+ call paths (10+ files)

For every conclusion in research.md:
- Attach file:line evidence. No evidence = mark as ❓ unverified
- "Should be fine" is NOT a valid conclusion — verify or mark ❓
- Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified

Simple changes may skip research and go straight to plan.md.
EOF

exit 0