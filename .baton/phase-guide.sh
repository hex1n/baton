#!/bin/sh
# phase-guide.sh — Detect current phase, output phase-specific guidance
# Version: 2.0
# Hook: SessionStart
# Also handles: stale plan archival detection

# --- Fail-open on unexpected errors ---
trap 'echo "⚠️ BATON phase-guide: unexpected error, skipping guidance" >&2; exit 0' HUP INT TERM

PLAN_NAME="${BATON_PLAN:-plan.md}"
# SYNCED: find_plan — same algorithm in write-lock.sh, stop-guard.sh, bash-guard.sh
PLAN=""
d="$(pwd)"
while true; do
    [ -f "$d/$PLAN_NAME" ] && { PLAN="$d/$PLAN_NAME"; break; }
    p="$(dirname "$d")"
    [ "$p" = "$d" ] && break
    d="$p"
done

# --- Archival detection (only when NOT in implement phase) ---
if [ -n "$PLAN" ] && grep -q '\[x\]' "$PLAN" 2>/dev/null \
   && ! grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    echo "📋 Stale $PLAN_NAME with completed tasks. Archive before new task:" >&2
    echo "   mkdir -p plans && mv $PLAN_NAME plans/\${PLAN_NAME%.md}-\$(date +%Y-%m-%d)-topic.md" >&2
    echo "   mv research.md plans/research-\$(date +%Y-%m-%d)-topic.md" >&2
    echo "   💡 Tip: keep \"## Lessons Learned\" section in archived plans for future reference" >&2
    echo "" >&2
fi

# --- Phase-specific guidance ---
if [ -z "$PLAN" ]; then
    cat >&2 << 'EOF'
📍 RESEARCH / PLAN phase — create plan.md when ready
Research (3+ files or unfamiliar area):
  Scope | Architecture (file:line refs) | Constraints | Patterns | Risks | Key files | Coverage (N/M files read)
Bug fix shortcut:
  Error | Reproduction | Root Cause | Fix Scope | Regression Risk
Context: 10+ files → use subagents, write findings to research.md
Evidence: file:line for every claim. Inferences as "Inference:". Unknowns as "Open Questions:"
When research is sufficient, write plan.md (research findings can go directly into it).
EOF
elif grep -q '<!-- BATON:GO -->' "$PLAN" 2>/dev/null; then
    cat >&2 << 'EOF'
📍 IMPLEMENT phase active — keep <!-- BATON:GO --> at top of plan.md (moving/deleting it re-locks)
- Consider /compact before starting (clear research context from window)
- 10+ file changes → start fresh session (plan.md = handoff doc)
- After each item: typecheck/build → mark [x] ✅
- After ALL items: full test suite, note result at bottom
- Stopping early? Append "## Lessons Learned" to plan.md (what worked / didn't / next)
- Rollback: checkpoints first, git revert for permanent
EOF
else
    cat >&2 << 'EOF'
📍 PLAN phase active
- Declare scope: files to modify + importers to verify
- Verification: concrete test cases (input → expected output), not "run tests"
  Specify WHICH tests and WHY they cover the change
- Self-review before human annotation:
  "3 biggest risks?" / "Files outside scope that could break?" / "What would a senior engineer question?"
  → Add ## Risks section to plan.md
- Annotation exit checklist:
  ✓ Every modified file has acceptance criteria?
  ✓ Impact scope (importers/callers) declared?
  ✓ Risks + rollback strategy written in plan?
- Suggested plan.md structure: Goal | Scope | Approach | Risks | Verification
- Do NOT add todo checklist — wait for human review
- Review cycle: read plan → add inline comments → AI addresses → repeat → <!-- BATON:GO -->
EOF
fi

exit 0
