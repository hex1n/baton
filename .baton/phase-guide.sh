#!/bin/sh
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 3.0
# Hook: SessionStart
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
📍 IMPLEMENT phase — <!-- BATON:GO --> is set
Implement in Todo order. After each item: typecheck → mark [x].
After all items: run full test suite. Discover omission → stop, update plan, wait for confirmation.
EOF
    exit 0
fi

# State 3: ANNOTATION — plan exists, no GO
if [ -n "$PLAN" ]; then
    cat >&2 << 'EOF'
📍 ANNOTATION cycle — plan.md awaiting approval
Human may add annotations: [NOTE] [Q] [CHANGE] [DEEPER] [MISSING] [RESEARCH-GAP]
Respond to each annotation, record in Annotation Log.
Human annotations may not always be correct — explain issues with file:line evidence, offer alternatives.
Human will say "generate todolist" or add <!-- BATON:GO --> when satisfied.
EOF
    exit 0
fi

# State 4: PLAN — research exists, no plan
if [ -n "$RESEARCH" ]; then
    cat >&2 << 'EOF'
📍 PLAN phase — produce plan.md (based on research.md + requirements)
Include: what (referencing research), why, impact scope, risk mitigation.
Approach analysis: extract constraints → derive 2-3 approaches (feasibility + pros/cons) → recommend + reasoning.
Do NOT write todolist — generate only after human approves.
EOF
    exit 0
fi

# State 5: RESEARCH — nothing exists
cat >&2 << 'EOF'
📍 RESEARCH phase — produce research.md
Read code deeply, trace call chains to implementations (don't stop at interfaces).
Mark risks: ✅ confirmed safe / ❌ problem found / ❓ unverified. Attach file:line to every conclusion.
Simple changes may skip research and go straight to plan.md.
EOF

exit 0