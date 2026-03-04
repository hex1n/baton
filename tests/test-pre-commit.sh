#!/bin/bash
# test-pre-commit.sh — Tests for git pre-commit hook
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$SCRIPT_DIR/../.baton/git-hooks/pre-commit"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Helper: create a git repo with staged files
setup_repo() {
    d="$tmp/$1"
    mkdir -p "$d"
    (cd "$d" && git init -q && git config user.email "test@test.com" && git config user.name "test")
    cp "$HOOK" "$d/.git/hooks/pre-commit"
    chmod +x "$d/.git/hooks/pre-commit"
    echo "$d"
}

# ============================================================
echo "=== Test 1: No plan → block source commit ==="
d="$(setup_repo t1)"
echo "hello" > "$d/app.ts"
(cd "$d" && git add app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && git commit -m "test" 2>/dev/null); then
    echo "  FAIL: should block when no plan.md"
    FAIL=$((FAIL + 1))
else
    echo "  pass: blocked source commit without plan"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 2: Pure markdown commit → always allowed ==="
d="$(setup_repo t2)"
echo "# Notes" > "$d/research.md"
(cd "$d" && git add research.md)
TOTAL=$((TOTAL + 1))
if (cd "$d" && git commit -m "test" 2>/dev/null); then
    echo "  pass: allowed pure markdown commit"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should allow pure markdown commit"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: Plan without BATON:GO → block ==="
d="$(setup_repo t3)"
echo "# Plan" > "$d/plan.md"
(cd "$d" && git add plan.md && git commit -q -m "add plan")
echo "hello" > "$d/app.ts"
(cd "$d" && git add app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && git commit -m "test" 2>/dev/null); then
    echo "  FAIL: should block when plan has no BATON:GO"
    FAIL=$((FAIL + 1))
else
    echo "  pass: blocked commit — plan exists but no BATON:GO"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 4: Plan with BATON:GO + Todo → allow ==="
d="$(setup_repo t4)"
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/plan.md"
(cd "$d" && git add plan.md && git commit -q -m "add plan")
echo "hello" > "$d/app.ts"
(cd "$d" && git add app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && git commit -m "test" 2>/dev/null); then
    echo "  pass: allowed commit with BATON:GO"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should allow commit when plan has BATON:GO"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 5: BATON_BYPASS=1 → skip check ==="
d="$(setup_repo t5)"
# No plan, but bypass enabled
echo "hello" > "$d/app.ts"
(cd "$d" && git add app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && BATON_BYPASS=1 git commit -m "test" 2>/dev/null); then
    echo "  pass: bypass skipped check"
    PASS=$((PASS + 1))
else
    echo "  FAIL: BATON_BYPASS=1 should skip check"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 6: Custom BATON_PLAN → finds custom plan file ==="
d="$(setup_repo t6)"
printf '# Plan\n<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/my-plan.md"
(cd "$d" && git add my-plan.md && git commit -q -m "add plan")
echo "hello" > "$d/app.ts"
(cd "$d" && git add app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && BATON_PLAN="my-plan.md" git commit -m "test" 2>/dev/null); then
    echo "  pass: found custom plan file via BATON_PLAN"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should find custom plan file"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 7: Mixed commit (md + source) without GO → block ==="
d="$(setup_repo t7)"
echo "# Plan" > "$d/plan.md"
(cd "$d" && git add plan.md && git commit -q -m "add plan")
echo "# Notes" > "$d/notes.md"
echo "hello" > "$d/app.ts"
(cd "$d" && git add notes.md app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && git commit -m "test" 2>/dev/null); then
    echo "  FAIL: should block mixed commit without GO"
    FAIL=$((FAIL + 1))
else
    echo "  pass: blocked mixed commit without BATON:GO"
    PASS=$((PASS + 1))
fi

# ============================================================
echo ""
echo "=== Test 8: Plan with BATON:GO but no Todo → allow (write-lock is minimal) ==="
d="$(setup_repo t8)"
printf '# Plan\n<!-- BATON:GO -->\n' > "$d/plan.md"
(cd "$d" && git add plan.md && git commit -q -m "add plan")
echo "hello" > "$d/app.ts"
(cd "$d" && git add app.ts)
TOTAL=$((TOTAL + 1))
if (cd "$d" && git commit -m "test" 2>/dev/null); then
    echo "  pass: allowed commit — GO present, Todo check removed"
    PASS=$((PASS + 1))
else
    echo "  FAIL: should allow when plan has GO (Todo check removed)"
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
