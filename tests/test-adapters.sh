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
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)"
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
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)" || true
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
OUTPUT="$(cd "$d" && printf '%s' "$JSON" | sh "$d/.baton/adapters/adapter-cursor.sh" 2>/dev/null)" || true
if echo "$OUTPUT" | grep -q '"decision":"deny"'; then
    echo "  pass: cursor adapter blocks when no plan"
    PASS=$((PASS + 1))
else
    echo "  FAIL: expected deny when no plan, got: $OUTPUT"
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
