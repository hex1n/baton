#!/usr/bin/env bash
# run-smoke-tests.sh — Baton v2.1 smoke tests
# Covers CLI commands, state machine phases (all 9), and phase-lock behavior.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BATON="$BATON_ROOT/bin/baton"

# Setup temp workspace
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT
cd "$WORK_DIR"

export BATON_GLOBAL="$BATON_ROOT"

pass=0 fail=0 total=0

run_test() {
    total=$((total + 1))
    local name="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        echo "  ✓ $name"
        pass=$((pass + 1))
    else
        echo "  ✗ $name"
        fail=$((fail + 1))
    fi
}

assert_output_contains() {
    local cmd_output="$1"
    local expected="$2"
    echo "$cmd_output" | grep -q "$expected"
}

echo "═══ Baton v2.1 Smoke Tests ═══"
echo

# ── CLI basics ──────────────────────────────────────────────

echo "CLI Basics:"

run_test "baton version" bash "$BATON" version

run_test "baton help" bash -c "bash '$BATON' --help | grep -q 'new-task'"

run_test "baton init creates .baton/" bash -c "
    cd '$WORK_DIR' && mkdir init-test && cd init-test
    bash '$BATON' init >/dev/null 2>&1
    [ -f .baton/project-config.json ]
"

run_test "baton doctor passes after init" bash -c "
    cd '$WORK_DIR/init-test'
    bash '$BATON' doctor >/dev/null 2>&1
"

# ── Task lifecycle ──────────────────────────────────────────

echo ""
echo "Task Lifecycle:"

run_test "new-task creates task dir" bash -c "
    cd '$WORK_DIR' && mkdir lifecycle && cd lifecycle
    bash '$BATON' init >/dev/null 2>&1
    bash '$BATON' new-task t1 >/dev/null 2>&1
    [ -d .baton/tasks/t1 ]
"

run_test "new-task sets active task" bash -c "
    cd '$WORK_DIR/lifecycle'
    [ -f .baton/active-task ] && grep -q 't1' .baton/active-task
"

run_test "active shows current task" bash -c "
    cd '$WORK_DIR/lifecycle'
    bash '$BATON' active | grep -q 't1'
"

run_test "abandon marks task" bash -c "
    cd '$WORK_DIR/lifecycle'
    bash '$BATON' abandon t1 >/dev/null 2>&1
    [ -f .baton/tasks/t1/.abandoned ]
"

# ── State machine: all 9 phases ─────────────────────────────

echo ""
echo "State Machine (9 phases):"

# Fresh project for state machine tests
STATE_DIR="$WORK_DIR/state-test"
mkdir -p "$STATE_DIR"
cd "$STATE_DIR"
bash "$BATON" init >/dev/null 2>&1

run_test "research (not started) detected" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' new-task sm1 >/dev/null 2>&1
    rm -f .baton/tasks/sm1/research.md
    bash '$BATON' active sm1 2>&1 | grep -q 'research (not started)'
"

run_test "research (draft) detected" bash -c "
    cd '$STATE_DIR'
    echo '<!-- RESEARCH-STATUS: DRAFT -->' > .baton/tasks/sm1/research.md
    bash '$BATON' active sm1 2>&1 | grep -q 'research (draft)'
"

run_test "plan (ready) after research CONFIRMED" bash -c "
    cd '$STATE_DIR'
    echo '<!-- RESEARCH-STATUS: CONFIRMED -->' > .baton/tasks/sm1/research.md
    bash '$BATON' active sm1 2>&1 | grep -q 'plan (ready)'
"

run_test "plan (draft) detected" bash -c "
    cd '$STATE_DIR'
    cat > .baton/tasks/sm1/plan.md << 'PLAN'
# Plan
<!-- STATUS: DRAFT -->
## Design
PLAN
    bash '$BATON' active sm1 2>&1 | grep -q 'plan (draft)'
"

run_test "annotation detected" bash -c "
    cd '$STATE_DIR'
    cat > .baton/tasks/sm1/plan.md << 'PLAN'
# Plan
<!-- STATUS: DRAFT -->
## Annotation log
### Round 1
- Changed X to Y
PLAN
    bash '$BATON' active sm1 2>&1 | grep -q 'annotation'
"

run_test "approved (generating todo) detected" bash -c "
    cd '$STATE_DIR'
    cat > .baton/tasks/sm1/plan.md << 'PLAN'
# Plan
<!-- STATUS: APPROVED -->
## Design
No todo section yet.
PLAN
    bash '$BATON' active sm1 2>&1 | grep -q 'approved'
"

run_test "slice phase detected (Todo exists, no Slices)" bash -c "
    cd '$STATE_DIR'
    cat > .baton/tasks/sm1/plan.md << 'PLAN'
# Plan
<!-- STATUS: APPROVED -->
## Design
## Todo
- [ ] Item 1
- [ ] Item 2
PLAN
    bash '$BATON' active sm1 2>&1 | grep -q 'slice'
"

run_test "implement detected (Todo + Slices exist, items unchecked)" bash -c "
    cd '$STATE_DIR'
    cat > .baton/tasks/sm1/plan.md << 'PLAN'
# Plan
<!-- STATUS: APPROVED -->
## Todo
- [ ] Item 1
- [ ] Item 2
## Context Slices
### slice-1
Files to modify: foo.js
PLAN
    bash '$BATON' active sm1 2>&1 | grep -q 'implement'
"

run_test "verify detected (all items checked)" bash -c "
    cd '$STATE_DIR'
    cat > .baton/tasks/sm1/plan.md << 'PLAN'
# Plan
<!-- STATUS: APPROVED -->
## Todo
- [x] Item 1
- [x] Item 2
## Context Slices
### slice-1
Files to modify: foo.js
PLAN
    bash '$BATON' active sm1 2>&1 | grep -q 'verify'
"

run_test "review detected (verification DONE, no review.md)" bash -c "
    cd '$STATE_DIR'
    echo 'TASK-STATUS: DONE' > .baton/tasks/sm1/verification.md
    rm -f .baton/tasks/sm1/review.md
    bash '$BATON' active sm1 2>&1 | grep -q 'review'
"

run_test "review (blocking) detected" bash -c "
    cd '$STATE_DIR'
    echo 'BLOCKING: lint failure' > .baton/tasks/sm1/review.md
    bash '$BATON' active sm1 2>&1 | grep -q 'review (blocking'
"

run_test "done detected (review exists, no BLOCKING)" bash -c "
    cd '$STATE_DIR'
    echo 'All clear. No issues.' > .baton/tasks/sm1/review.md
    bash '$BATON' active sm1 2>&1 | grep -q 'done'
"

# ── Quick-path ──────────────────────────────────────────────

echo ""
echo "Quick-path:"

run_test "new-task --quick creates .quick-path" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' new-task qp1 --quick >/dev/null 2>&1
    [ -f .baton/tasks/qp1/.quick-path ]
"

run_test "quick-path starts at plan phase" bash -c "
    cd '$STATE_DIR'
    grep -q 'qp1 plan' .baton/active-task
"

# ── baton next guidance ─────────────────────────────────────

echo ""
echo "baton next guidance:"

run_test "next shows slice guidance" bash -c "
    cd '$STATE_DIR'
    # Set up a task in slice phase
    bash '$BATON' new-task ng1 >/dev/null 2>&1
    echo '<!-- RESEARCH-STATUS: CONFIRMED -->' > .baton/tasks/ng1/research.md
    cat > .baton/tasks/ng1/plan.md << 'PLAN'
# Plan
<!-- STATUS: APPROVED -->
## Todo
- [ ] Item 1
PLAN
    bash '$BATON' active ng1 >/dev/null 2>&1
    bash '$BATON' next 2>&1 | grep -q 'context-slice'
"

run_test "next shows review guidance" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' new-task ng2 >/dev/null 2>&1
    echo '<!-- RESEARCH-STATUS: CONFIRMED -->' > .baton/tasks/ng2/research.md
    echo '<!-- STATUS: APPROVED -->' > .baton/tasks/ng2/plan.md
    echo 'TASK-STATUS: DONE' > .baton/tasks/ng2/verification.md
    bash '$BATON' active ng2 >/dev/null 2>&1
    bash '$BATON' next 2>&1 | grep -q 'code-reviewer'
"

run_test "next shows approved guidance" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' new-task ng3 >/dev/null 2>&1
    echo '<!-- RESEARCH-STATUS: CONFIRMED -->' > .baton/tasks/ng3/research.md
    cat > .baton/tasks/ng3/plan.md << 'PLAN'
# Plan
<!-- STATUS: APPROVED -->
## Design
No todo yet.
PLAN
    bash '$BATON' active ng3 >/dev/null 2>&1
    bash '$BATON' next 2>&1 | grep -q 'plan-first-plan'
"

# ── Session start ───────────────────────────────────────────

echo ""
echo "Session start hook:"

run_test "session-start runs without error" bash -c "
    cd '$STATE_DIR'
    bash '$BATON_ROOT/hooks/session-start.sh' >/dev/null 2>&1
"

run_test "session-start shows REQUIRED ACTION for active task" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' active ng3 >/dev/null 2>&1
    bash '$BATON_ROOT/hooks/session-start.sh' 2>&1 | grep -q 'REQUIRED ACTION'
"

# ── Doctor ──────────────────────────────────────────────────

echo ""
echo "Doctor:"

run_test "doctor checks workflow protocol" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' doctor 2>&1 | grep -qi 'protocol'
"

run_test "doctor checks all 8 skills" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' doctor 2>&1 | grep -q '8 skills'
"

# ── Constraints ─────────────────────────────────────────────

echo ""
echo "Constraints:"

run_test "constraints command works" bash -c "
    cd '$STATE_DIR'
    bash '$BATON' constraints 2>&1 | grep -q 'HC-000'
"

# ── Summary ─────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════"
echo "  Results: $pass passed, $fail failed (of $total)"
echo "═══════════════════════════════════════"

if [ $fail -gt 0 ]; then
    exit 1
fi
