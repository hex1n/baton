#!/bin/bash
# test-cli.sh — Tests for bin/baton CLI
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BATON_CLI="$SCRIPT_DIR/../bin/baton"
SETUP="$SCRIPT_DIR/../setup.sh"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Use a temporary BATON_HOME to avoid polluting real config
export BATON_HOME="$tmp/baton_home"
mkdir -p "$BATON_HOME"
# Copy required files into fake BATON_HOME
cp -r "$SCRIPT_DIR/../.baton" "$BATON_HOME/.baton"
cp "$SETUP" "$BATON_HOME/setup.sh"
mkdir -p "$BATON_HOME/bin"
cp "$BATON_CLI" "$BATON_HOME/bin/baton"

# ============================================================
echo "=== Test 1: baton help ==="
TOTAL=$((TOTAL + 1))
if bash "$BATON_CLI" help 2>&1 | grep -q 'plan-first workflow'; then
    echo "  pass: help shows usage text"
    PASS=$((PASS + 1))
else
    echo "  FAIL: help output missing expected text"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2: baton list — empty registry ==="
TOTAL=$((TOTAL + 1))
if bash "$BATON_CLI" list 2>&1 | grep -q 'No projects'; then
    echo "  pass: list shows 'No projects' when empty"
    PASS=$((PASS + 1))
else
    echo "  FAIL: list should show 'No projects'"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: baton init — registers project ==="
d="$tmp/proj1" && mkdir -p "$d/.claude"
(cd "$d" && git init -q)
TOTAL=$((TOTAL + 1))
if BATON_SKIP=pre-commit bash "$BATON_CLI" init "$d" > /dev/null 2>&1; then
    echo "  pass: init succeeded"
    PASS=$((PASS + 1))
else
    echo "  FAIL: init failed"
    FAIL=$((FAIL + 1))
fi
# Check registry
TOTAL=$((TOTAL + 1))
_abs="$(cd "$d" && pwd)"
if grep -qF "$_abs" "$BATON_HOME/projects.list" 2>/dev/null; then
    echo "  pass: project registered in projects.list"
    PASS=$((PASS + 1))
else
    echo "  FAIL: project not in registry"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: baton list — shows registered project ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(timeout 10 bash "$BATON_CLI" list 2>&1 || true)"
if echo "$OUTPUT" | grep -q 'Registered projects'; then
    echo "  pass: list shows registered project"
    PASS=$((PASS + 1))
elif echo "$OUTPUT" | grep -qF "$_abs"; then
    echo "  pass: list shows project path"
    PASS=$((PASS + 1))
else
    echo "  FAIL: list should show registered project, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5: baton doctor — checks installation ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" doctor "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'Checking baton installation'; then
    echo "  pass: doctor runs"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor output unexpected"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'write-lock.sh'; then
    echo "  pass: doctor checks scripts"
    PASS=$((PASS + 1))
else
    echo "  FAIL: doctor should check scripts"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: baton status — shows phase ==="
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'Phase:'; then
    echo "  pass: status shows phase"
    PASS=$((PASS + 1))
else
    echo "  FAIL: status should show phase"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: baton status — RESEARCH phase (no plan) ==="
TOTAL=$((TOTAL + 1))
if echo "$OUTPUT" | grep -q 'RESEARCH'; then
    echo "  pass: status shows RESEARCH when no plan"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show RESEARCH phase"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 8: baton status — IMPLEMENT phase (plan with GO) ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'IMPLEMENT'; then
    echo "  pass: status shows IMPLEMENT when plan has GO + Todo"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show IMPLEMENT phase, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 9: baton status — ARCHIVE phase (all todos done) ==="
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [x] Step 1\n- [x] Step 2\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" status "$d" 2>&1)"
if echo "$OUTPUT" | grep -q 'ARCHIVE'; then
    echo "  pass: status shows ARCHIVE when all todos complete"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should show ARCHIVE phase, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 10: baton uninstall — removes and deregisters ==="
TOTAL=$((TOTAL + 1))
if BATON_SKIP=pre-commit bash "$BATON_CLI" uninstall "$d" > /dev/null 2>&1; then
    echo "  pass: uninstall succeeded"
    PASS=$((PASS + 1))
else
    echo "  FAIL: uninstall failed"
    FAIL=$((FAIL + 1))
fi
TOTAL=$((TOTAL + 1))
if ! grep -qF "$_abs" "$BATON_HOME/projects.list" 2>/dev/null; then
    echo "  pass: project removed from registry"
    PASS=$((PASS + 1))
else
    echo "  FAIL: project still in registry after uninstall"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 11: baton update --all — no projects ==="
# Clear registry
> "$BATON_HOME/projects.list"
TOTAL=$((TOTAL + 1))
OUTPUT="$(bash "$BATON_CLI" update --all 2>&1)"
if echo "$OUTPUT" | grep -q 'No projects'; then
    echo "  pass: update --all shows no projects"
    PASS=$((PASS + 1))
else
    echo "  FAIL: update --all should show no projects"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
if [ "$FAIL" -gt 0 ]; then
    echo "FAILED"
    exit 1
else
    echo "ALL PASSED"
    exit 0
fi
