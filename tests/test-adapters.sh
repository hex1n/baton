#!/bin/bash
# test-adapters.sh — Tests for cross-IDE adapters (Cursor)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ADAPTERS="$SCRIPT_DIR/../.baton/adapters"
PASS=0
FAIL=0
TOTAL=0

tmp="$(mktemp -d)"
trap 'rm -rf $tmp' EXIT

# Helper: set up test directory with write-lock and adapter
setup_cursor() {
    d="$tmp/$1" && mkdir -p "$d/.baton/adapters" "$d/.baton/hooks"
    cp "$SCRIPT_DIR/../.baton/hooks/write-lock.sh" "$d/.baton/hooks/write-lock.sh"
    cp "$SCRIPT_DIR/../.baton/hooks/_common.sh" "$d/.baton/hooks/_common.sh"
    chmod +x "$d/.baton/hooks/write-lock.sh"
    cp "$ADAPTERS/adapter-cursor.sh" "$d/.baton/adapters/adapter-cursor.sh"
    chmod +x "$d/.baton/adapters/adapter-cursor.sh"
    echo "$d"
}

# ============================================================
echo "=== Test 1: Cursor adapter — allowed with BATON:GO ==="
d="$(setup_cursor t1)"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | bash "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)"
if echo "$OUTPUT" | grep -q '"decision":"allow"'; then
    echo "  pass: cursor adapter returns allow when BATON:GO present"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected allow, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 2: Cursor adapter — blocked without BATON:GO ==="
d="$(setup_cursor t2)"
echo "# Plan" > "$d/plan.md"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | bash "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"decision":"deny"'; then
    echo "  pass: cursor adapter returns deny when no BATON:GO"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected deny, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
echo ""
echo "=== Test 3: Cursor adapter — no plan → denied ==="
d="$(setup_cursor t3)"
JSON='{"tool_input":{"file_path":"src/app.ts"}}'
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | bash "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"decision":"deny"'; then
    echo "  pass: cursor adapter blocks when no plan"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected deny when no plan, got: $OUTPUT"
    FAIL=$((FAIL + 1))
fi

# ============================================================
# Codex adapter tests
# ============================================================

setup_codex() {
    d="$tmp/$1" && mkdir -p "$d/.baton/adapters" "$d/.baton/hooks"
    cp "$SCRIPT_DIR/../.baton/hooks/phase-guide.sh" "$d/.baton/hooks/phase-guide.sh"
    cp "$SCRIPT_DIR/../.baton/hooks/stop-guard.sh" "$d/.baton/hooks/stop-guard.sh"
    cp "$SCRIPT_DIR/../.baton/hooks/_common.sh" "$d/.baton/hooks/_common.sh"
    chmod +x "$d/.baton/hooks/phase-guide.sh" "$d/.baton/hooks/stop-guard.sh"
    cp "$ADAPTERS/adapter-codex.sh" "$d/.baton/adapters/adapter-codex.sh"
    chmod +x "$d/.baton/adapters/adapter-codex.sh"
    echo "$d"
}

echo ""
echo "=== Test 4: Codex adapter — phase-guide output on stdout ==="
d="$(setup_codex t4)"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && bash "$d/.baton/adapters/adapter-codex.sh" phase-guide 2>/dev/null)" || true
if [ -n "$OUTPUT" ]; then
    echo "  pass: codex adapter produces stdout output for phase-guide"
    PASS=$((PASS + 1))
else
    echo "  FAIL: codex adapter produced no stdout for phase-guide"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Test 5: Codex adapter — stderr is redirected to stdout ==="
d="$(setup_codex t5)"
printf '<!-- BATON:GO -->\n## Todo\n- [ ] Step 1\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
# phase-guide normally writes to stderr; codex adapter should capture it to stdout
STDERR_OUTPUT="$(cd "$d" && bash "$d/.baton/adapters/adapter-codex.sh" phase-guide 2>&1 1>/dev/null)" || true
STDOUT_OUTPUT="$(cd "$d" && bash "$d/.baton/adapters/adapter-codex.sh" phase-guide 2>/dev/null)" || true
if [ -n "$STDOUT_OUTPUT" ] && [ -z "$STDERR_OUTPUT" ]; then
    echo "  pass: codex adapter redirects stderr to stdout (no stderr leak)"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected output on stdout only (stdout='${STDOUT_OUTPUT:0:40}', stderr='${STDERR_OUTPUT:0:40}')"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "=== Test 6: Codex adapter — unknown hook name fails ==="
d="$(setup_codex t6)"
TOTAL=$((TOTAL + 1))
if cd "$d" && bash "$d/.baton/adapters/adapter-codex.sh" unknown-hook 2>/dev/null; then
    echo "  FAIL: expected failure for unknown hook name"
    FAIL=$((FAIL + 1))
else
    echo "  pass: codex adapter rejects unknown hook name"
    PASS=$((PASS + 1))
fi

echo ""
echo "=== Test 7: Codex adapter — stop-guard produces output ==="
d="$(setup_codex t7)"
printf '<!-- BATON:GO -->\n## Todo\n- [x] ✅ Step 1\n' > "$d/plan.md"
TOTAL=$((TOTAL + 1))
OUTPUT="$(cd "$d" && bash "$d/.baton/adapters/adapter-codex.sh" stop-guard 2>/dev/null)" || true
# stop-guard should produce some output (completion check or similar)
if [ -n "$OUTPUT" ]; then
    echo "  pass: codex adapter produces stdout output for stop-guard"
    PASS=$((PASS + 1))
else
    echo "  FAIL: codex adapter produced no stdout for stop-guard"
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
